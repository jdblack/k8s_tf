# Progress

## What works (verified live unless noted)

- **Core platform** — Calico (tigera-operator), MetalLB (L2), external-dns
  (rfc2136 → bind9, authoritative for `vn.linuxguru.net` only), Longhorn, SeaweedFS +
  CSI, cert-manager (pinned `v1.21.1`; **`letsencrypt` DNS-01 with the zone pinned signs
  all 19 hosts** — 16 declared here + the 3 `ai` hosts in the external repo; no workload
  injects a private CA any more and `linuxguru-ca` is dormant, unreferenced, expiring
  2027-08-14), authentik, kube-prometheus-stack + Grafana SSO, Harbor, Argo CD, WireGuard
  operator, Gateway API CRDs + shared NGF gateways.
- **Exposure model** — `gateway/expose` is used by every app and the cert is
  auto-provisioned from the ListenerSet annotation (no hand-written `Certificate`s).
  **No VIP is pinned**: every gateway/LoadBalancer takes a MetalLB pool address and is
  reached by name (external-dns → bind9; vaultwarden's A record reads the private
  gateway's live Service). Today's assignments — public `.101`, private `.100`,
  media-private `.106`, plex `.104`, blender `.103`, qbittorrent-torrent `.105`, wg
  `.107` — are assignments, not config. The only two addresses DNS cannot cover are the
  router NAT rules (WAN 443 → public gateway, WAN 21010 → torrent); see
  `modules/network/gateways.tf`.
- **Firewall library** — `policy` renderer + `basic_internet`, `limited_ingress`,
  `allow_api`. Media is locked down (2026-09-12). The staged/preview mechanism is proven
  on `argo`.
- **Core-apply landmine — FIXED 2026-09-16.** Was: a core apply aborting with
  `Provider produced inconsistent final plan ... block count changed from 1 to 2`,
  triggered by **any pending change in a module listed in the caller's `depends_on`**
  (cert_man as readily as storage), because a module-level `depends_on` covers every
  resource *and data source*: the `kubernetes` Endpoints read inside authentik's
  `allow_api` was deferred to apply time, so the policy planned a *guessed* `to` block
  count (1 = ClusterIP) while the apply read the real 2. **Fix:** the read moved to
  `stacks/core/core.tf` (`data.kubernetes_endpoints_v1.kubernetes` +
  `local.api_peer_ips`), passed down through a new optional `api_peer_ips` variable on
  `allow_api`, `basic_internet`, `modules/auth/authentik/core` and
  `modules/cert_manager`; setting it disables the module's own counted read
  (`count = … && var.api_peer_ips == null`), so no `depends_on` can defer it, and the
  `null` default leaves mantle's media call untouched. Hardcoding control-plane IPs was
  considered and rejected (`.clinedocs/calico-netpols.md`). **Verified:** core plans No
  changes; a deliberate pending change in `module.storage` then applied clean (the case
  that used to abort) with 0 `will be read during apply` lines; mantle No changes with
  media's in-module read still working. Old-behaviour evidence: `/tmp/core.apply.log`
  (2026-09-15 01:14), `/tmp/core-apply.txt`, `/tmp/relabel.txt`. **Residual:** a *new*
  module-level `depends_on` on a caller of a firewall with `allow_to_k8sapi = true`
  (argo today — it has none) re-arms it; invariant in `.clinedocs/calico-netpols.md`.
- **IdP-first login — Harbor only; the Argo apps keep their own login pages,
  deliberately (2026-09-15).** Harbor uses its native `primary_auth_mode`. Argo CD and
  Argo Workflows got a `gateway/redirect_route` hijacking `Exact /` at their OIDC
  entrypoint; it worked until Argo CD's target lost its `return_url`, so the callback
  (falling back to `/`) re-entered the same rule — an instant loop whose only symptoms
  were Chrome's ERR_TOO_MANY_REDIRECTS and Argo CD's `data length is less than nonce
  size`. Removed, not repaired: no native auto-redirect switch exists for either app.
  Both hosts serve their own login page and the SSO entrypoints (`/auth/login`,
  `/oauth2/redirect?redirect=/workflows`) still hand off to authentik, so a bookmark is
  still one click. One route destroyed in each of `core` and `mantle`; both then plan
  empty. Full postmortem + rebuild recipe under "Evolution" below.
- **mantle workloads** — media (sonarr/radarr/prowlarr/bazarr/plex/qbittorrent, all
  outpost-fronted except the torrent port), blender (Samba + mDNS Bonjour advertiser that
  macOS Finder needs), whisker (flow-log UI, SSO-gated), seaweedfs-admin (SSO-gated),
  Grafana/Harbor/Argo OIDC + deploy keys.
- **vaultwarden** — deployment + PVC + Service + Route53 A record, publicly trusted cert
  on a private gateway, admin panel disabled; snapshots come from the cluster-wide policy
  below (per-app `backup.tf` retired). Drift test documented and passing (2026-09-14).
- **apps stack** — ArgoCD `AppProject` + app-of-apps `Application` for `ai`; all three
  live from the external deployments dir, Synced/Healthy on `library` charts: `ollama`
  `1.78.0`, `corsless` `0.0.26`, `llm-embedder` `0.0.79`. The dead-on-404 state was the
  registry split-brain (see `activeContext.md`) — fixed 2026-09-15 by repointing
  everything at `library`, seeding helm's credential store, making both charts render
  `extraObjects` and publishing `library/corsless-helm:0.0.26`. `llm-embedder` verified:
  5/5 pods on `library/llm-embedder:v0.0.79`, `/health` answers through the gateway,
  `/embed` → 200 with a 1024-dim vector (the `retrival.query` typo that 500'd every call
  is gone from the *shipped* image only — the source fix had to be republished to count).
  Known gap: `llm-embedder` accepts `prompt` but ignores it (`EmbedService.embedding()`
  hardcodes `retrieval.query`), so a passage-side caller cannot ask for
  `retrieval.passage` — design gap, not a bug.
- **Longhorn snapshots are cluster-wide, TF-owned and audited** —
  `modules/storage/longhorn_jobs.tf` holds three jobs (`snapshot-daily` 03:00,
  `snapshot-weekly` Sun 04:00, `snapshot-monthly` 28th 05:00, all UTC, `retain: 2`) and
  the enrolment table (8 PVCs covered, 7 deliberately `skip`);
  `modules/storage/snapshot_labeler.tf` is the **only** writer of the
  `recurring-job-group.longhorn.io/*` labels, and it writes them onto the Volume CRs
  because a labelled PVC *replaces* the volume's whole group set rather than merging
  (that trap cost the vaultwarden volume its enrolment mid-migration, and is why no PVC
  here carries those labels). No job may ever list the `default` group — Longhorn stamps
  every new unlabelled volume into it. Coverage audit + verified restore runbook:
  `modules/storage/disaster_recovery.md`.

## Code written, not yet applied

All in-place-only; all three stacks `validate`; plans saved in `/tmp/core.tfplan` and
`/tmp/mantle.tfplan`.

- **Repo hygiene pass (2026-09-16)** — `helm`/`random` provider versions pinned in all
  three stacks (core's lock moved `random` 3.7.2 → 3.8.1); every chart version now lives
  in its module's `variables.tf` (`helm_version`, or `helm_<chart>_version` in the
  multi-chart `network`/`storage` modules; `chart_version` renamed to match); every
  `helm_release` sets `wait = true` + `timeout = 600`; Grafana's OIDC placeholders are
  static `unset` instead of `random_uuid`/`random_password` (those two resources are
  destroyed; the Secret object is untouched, `ignore_changes = [data]` still holds);
  `modules/monitoring/grafana_oidc/auth.tf` → `main.tf`; mantle's provider data sources →
  `stacks/mantle/data.tf`; qbittorrent pinned to
  `lscr.io/linuxserver/qbittorrent:5.2.3_v2.0.14-ls475` + `strategy: Recreate`; blender's
  samba image pinned to `dockurr/samba:4.23.10` (upstream publishes version tags, so no
  avahi-style digest pin); radarr/bazarr moved to sonarr's `1000:1000` securityContext
  (they were `1000:65534`, the chart's default group, i.e. the shared-`media`-PVC
  `EACCES` generator). Side effect worth knowing: sonarr's `image.imagePullPolicy` was a
  chart no-op, so that fix makes sonarr genuinely honour `pullPolicy: Always` on a
  floating `tag = "4"`. Plans: core 0/17/2, mantle 0/9/0.
- **VIP policy: every gateway/LB floats, names are the interface (2026-09-16).**
  `gateway_ips` deleted from `modules/network` (with it tfvars `network_ingress` and the
  `stacks/core/core.tf` argument, its only consumers), both shared gateways take pool
  VIPs like the media/plex/blender/wg Services always did, and `qbittorrent_torrent_lb_ip`
  is unset (variable kept as the re-pin escape hatch). DNS carries the load: external-dns
  → bind9 for `.vn`, and vaultwarden's A record reads the private gateway's live
  data-plane Service (`kubernetes_service_v1` data source in
  `stacks/mantle/vaultwarden.tf`). **Evidence that unpinning is inert** (throwaway LB
  probe): clearing `spec.loadBalancerIP` left the assigned IP in place (`.149`, 4 samples
  over 12 s), while **deleting and recreating** the same Service came back on a different
  pool IP (`.108` → `.102`). So an ordinary apply moves nothing; only the two NAT rules
  need re-pointing, and only on a recreate. Plans: core 0/17/2, mantle 0/10/0.


## What's left / open

- **Namespace ingress rollout** for every namespace except `media` — the main thread of
  work; method, first candidates and the missing `staged` flag are in `activeContext.md`.
- **Off-cluster backups: nothing has one.** No Longhorn `backupTarget`, so all 8 covered
  volumes share a failure domain with their snapshots and a lost cluster takes
  everything. Intended target: SeaweedFS S3 (`s3.vn.linuxguru.net`, TLS trusted
  in-cluster) — add a `BackupTarget` CR, then either flip the three snapshot jobs to
  `task = "backup"` or add parallel backup jobs, and update
  `modules/storage/disaster_recovery.md`'s "recovery, not backup" banner + Gaps section
  when it lands.
- **Retire the CA — deliberately deferred. Don't "finish" this without asking.** The
  private CA is kept on purpose in case it's wanted back (the issuer plumbing was
  collapsed onto `cert_authorities.default` 2026-09-15, so the CA is now one `private`
  key that nothing names). When it does happen: drop the `linuxguru-ca` ClusterIssuer +
  the `kube-certificates/linuxguru-ca` Secret + the `default/linuxguru-ca` ConfigMap +
  the module's `ca_certfile`/`ca_keyfile` `file()` inputs, then `~/.ssl/ca.crt` and the
  node trust store in `initial_setup.yml` (k8s repo). Nothing breaks while it lingers —
  but `~/.ssl/ca.*` must keep existing or `tofu plan` fails.
- **Snapshot enrolment asymmetry**: `sonarr-config` and `radarr-config` are skipped
  while `prowlarr-config`/`bazarr-config` get a monthly (2026-09-16 judgement call, not a
  principle — same kind of volume). One line in `snapshot_groups` each to fix.
- **`modules/storage/backup.yaml` is orphaned** — a hand-applied `VolumeSnapshot` of
  `sonarr-config`; nothing references it, and its `sonarr-config-snap` object still sits
  in `media` (14d old, `ReadyToUse`) on top of a now-`skip` volume. Delete both, or adopt
  the file properly.
- **Plex plugin volume**: `media/pms-config-plex-plex-media-server-0` is a VCT-driven
  volume holding the Plex plugin/config tree; switching plex to a `configExistingClaim`
  (one longhorn-backed PVC) would make it snapshottable like the rest instead of `skip`.
- **Nothing scrapes cert-manager** — no `ServiceMonitor`, no expiry `PrometheusRule`, so
  a failed renewal stays invisible until the cert expires (~30 days of slack at 2/3
  lifetime). Cheap win: ServiceMonitor on `kube-certificates/cert-manager:9402` +
  `certmanager_certificate_expiration_timestamp_seconds < 21d`.
- **Longhorn Grafana dashboard** not imported. **external-dns HTTPRoute-annotation
  publishing** unexplained for `.vn` names (it never published
  `certtest.vn.linuxguru.net` — understand before relying on automatic `.vn` DNS).
  **Whisker UI through the authentik proxy** unconfirmed.
- **`signups_allowed` must go back to `false`** after any first-account bootstrap
  (`stacks/mantle/vaultwarden.tf`; `signups_allowed = true` → register → back to
  `false`); see the vaultwarden README.
- **vaultwarden has nothing to scrape** — 1.37.3 dropped the metrics build (no
  `/metrics`, no `PROMETHEUS_ENABLED`, only `GET /alive`), so the module ships no
  ServiceMonitor. If upstream restores it, add `monitoring.tf` and add `monitoring` to
  the ingress guest list in `modules/vaultwarden/security.tf`.
- **Rebuild gaps that are hand work, not state:** authentik group membership is
  UI-managed → members must be re-added by hand; per-app one-time config (arr apps
  `AuthenticationMethod = External`; qBittorrent pod-CIDR WebUI whitelist + hard pod
  kill; vaultwarden first-account bootstrap); `library` exists by default in Harbor, so a
  rebuild is fine — but the hand-made `robot$jblack` permission on it is not recreated by
  anything.
- **Chart pinning debt** — Harbor, external-dns, snapshot-controller, metrics-server,
  prometheus-smartctl-exporter, argo-cd, argo-events all float, as does plex (whose chart
  "repository" is a `raw.githubusercontent.com` gh-pages path — pinning it means checking
  the chart still resolves, not just picking a version).
- **Optional**: a `posture` wrapper so a namespace states egress+ingress in one call
  instead of 2-4 module calls (deferred until after the rollout).
- **Accepted risks**: `goldmane:7443` readable by any pod (unfixable from TF); media
  NodePort soft spot (`nodeIP:nodePort` bypass); `ollama` has no auth in front of it.


## Evolution of decisions worth knowing

- `allow_ingress` → renamed `limited_ingress` (2026-09) because the old name read like a
  blanket allow when it is a lockdown with a guest list. Docs/paths only — no resources
  moved. The older `namespace_only` is gone too, replaced by `limited_ingress` with a
  one-namespace guest list, typed instead of `kubectl_manifest`.
- ntfy alerting was added and then removed (2026-09); Alertmanager runs stock `null`.
  Harbor's native `primary_auth_mode` is the **only** native IdP-first lever here.
- The `modules/security/trivy` module was removed 2026-09; its three empty namespace
  shells (`trivy-system`, `trivy-temp`, and the pointlessly-declared `kube-security` in
  `stacks/mantle/security.tf`) held nothing but `kube-root-ca.crt` + a `default`
  ServiceAccount and were deleted 2026-09-15 — the state Secret and lock Lease that went
  with them are listed under Traps.
- `.vn` hosts moved to Let's Encrypt on demand (DNS-01: no inbound reachability, no new
  Route53 zone). One host (`sonarr`) → 12 of 17 in a day, including a 9-host batch,
  proving "one host at a time" was over-cautious for leaf-only hosts. The last four
  (`auth.vn`, `harbor`, `grafana`, `argo-wf`) had to ride in the **same apply** as the
  deletions of their CA trust material, because the *replacing* knobs (Grafana's
  `SSL_CERT_FILE`, Workflows' bundle subPath mount) break their app's SSO if separated
  from the flip in either direction; the planned `ca_name` split turned out unnecessary.
  The per-app `cert_issuers` override maps (`modules/media`) and the module-level
  `cert_issuer`/`cert_issuers` pair were deleted 2026-09-15: a host now moves by changing
  `cert_authorities.default`, and a genuine per-host exception would be new plumbing, not
  a map.
- `.terraform` caches trimmed 2.5 GB → 1.5 GB (2026-09-15) by deleting only provably dead
  things (provider versions absent from the stack's `.terraform.lock.hcl`, module dirs no
  enabled `.tf` references, both dead `keycloak/keycloak` providers, the parked websites'
  module caches); all three stacks still planned `No changes`. **The remaining 1.5 GB is
  live and pinned — a wipe would only re-download it.**
- **WordPress deployments in `stacks/apps` were disabled** when the cluster moved from
  ingress-nginx to Gateway API (they expect `ingress_class`); reviving them means porting
  to `gateway/expose` and passing `cert_authorities.default`. `notbatz.com_website.tf.disabled`
  was **deleted outright** (2026-09-15) — `notbatz.com` has **no Route53 zone in this
  account** (only `linuxguru.net` and `emtho.com` are hosted here) so it could never
  resolve; its state Secret, lock Lease, 81 MB module cache and `modules.json` entry went
  with it. The sibling `ngoc_website.tf.disabled` (`www.emtho.com`) is deliberately
  **kept** — that zone does exist, so the file is the only record of the site's
  definition.
- Harbor's `library` project is **not TF-managed, on purpose**: it is Harbor's *default*
  project and the only thing TF needs is the name, to build the OCI URL in
  `modules/argo/mantle/argo-cd/repositories.tf`. Parameterizing it would add a knob whose
  one legal value is "the default", so the dead `argocd_devops.harbor_project` key was
  **deleted instead of wired** — same call for `argocd_devops.repo_name` (the module
  hardcodes the display name).
- **How the IdP-first attempt went, and why it's gone (2026-09-15; reversed the same
  day).** Harbor's `primary_auth_mode` is the only *native* lever, and the UI acts on it
  **client-side**, so `curl /` still answers 200 — verify via
  `/api/v2.0/systeminfo` (`primary_auth_mode:true`), *not* the `harbor-core` cm, which
  never carries that key. Argo CD's nearest lever is `admin.enabled: "false"` in
  `argocd-cm`; rejected, because the mantle stack's `argocd` provider authenticates as
  `admin`, so it would break every later apply (the real fix is a named `iac` apiKey
  account + RBAC `role:admin` + token, plus no UI break-glass — deferred as its own
  change). Workflows has no lever at all: its login page is hardcoded and
  `--auth-mode=sso` only means no password form. Faking it at the gateway was possible
  (`redirect_route`: one redirect-only `Exact /` rule, no `backendRefs`, so it outranks
  the app's own `PathPrefix /` route by match specificity) and it did work — but it
  pushed another program's OIDC callback semantics into a routing string, where no `plan`
  can see them break, and that is exactly how it looped. Module and both call sites
  deleted. If it is ever rebuilt: the match type must be `Exact` (`PathExact` fails CRD
  validation — not a Gateway API type), the route needs a distinct name
  (`<name>-sso-redirect`; the app already owns one named `<name>`), and
  `replaceFullPath` **must** carry the app's post-login target, because a callback
  without one falls back to `/` and closes the loop.


## Traps and invariants

- **Docs were aggressively compressed 2026-09-16** — root `README.md`, this file,
  `activeContext.md` and three module READMEs. Rule applied: each fact lives in exactly
  one doc (root README = map/hostnames, memory-bank = state and open work, module README
  = app detail), while every command, table, version pin and gotcha was kept. The
  pre-compression text of any file is at `git show HEAD:<path>` (these edits were still
  uncommitted).
- **`*.tf` comments were trimmed 2026-09-16** (same day as the docs pass above): one rule
  — keep what explains non-obvious behaviour or an HCL/provider constraint, drop
  narrative history, verification dates, README pointers, design rationale and code
  restatements. Surviving examples worth not re-deleting: the JMESPath `&&`/`||`
  precedence parens (Grafana), the RWO-volume RollingUpdate deadlock, the control-plane
  scraper loopback gotcha, the Helm CRD upgrade hole, authentik group-name matching for
  argo-cd RBAC, argo-workflows `redirect_uri` scheme pin, plex's
  `externalTrafficPolicy=Local` firewall requirement, blender's mDNS/hostNetwork
  selector-collision trap, the post-DNAT egress semantics in `firewalls/allow_api`, the
  MetalLB-VIP/router-rule coupling, the Longhorn-labelled-PVC group-set replacement.
  **One casualty, caught by `validate`:** the trim silently took
  `variable "private_gateway_ip"` out of `modules/vaultwarden/variables.tf` along with
  its comment (mantle red with "An argument named private_gateway_ip is not expected
  here" until restored). **Lesson:** after any "comments only" pass, diff the *removed
  non-comment* lines (`git diff -U0 -- '*.tf' | grep '^-' | grep -v '^-[[:space:]]*#'`)
  and eyeball each one, then `tofu fmt -recursive -check` + `tofu validate` per stack.
  Clean as of 2026-09-16; the only remaining removed code lines are a variable
  `description` reword and a blank line.
- **State lives in the Kubernetes backend** (`kube-system`, `secret_suffix =
  core|mantle|deployment`), so an interrupted command leaves no local lock file — it
  leaves `tfstate-default-<stack>-lock`, and a local `ls` for `*.tfstate.lock.info`
  proves nothing. Clear it with
  `tofu -chdir=stacks/<stack> force-unlock -force <ID>` once `ps` shows no live `tofu`
  client (an interrupted `plan` holds it with `OperationTypePlan` and has written no
  state).
- **No `moved` blocks left anywhere (2026-09-16)** — the 28 accumulated by the `expose`
  migration (2026-09-12), the `firewalls/policy` extraction and the authentik group's
  `count` were all spent: state held only destination addresses, so deleting them left
  `core` and `mantle` planning **No changes**. A `moved` block is a one-shot: keep it
  while it still has state to rewrite, delete it immediately after the apply that
  consumed it (`tofu state list` is how you tell). Leaving one behind re-arms the old
  address — reintroduce `module.listener_set` anywhere and the block fires again against
  the new object. Re-add shape + rationale: `modules/network/gateway/expose/README.md`.
- **Sweeps already done (2026-09-15) — don't re-hunt these.** Orphan `letsencrypt-http`
  ClusterIssuer + its `letsencrypt-http-key` account key deleted (HTTP-01 leftover, in no
  `.tf`, referenced by no Certificate — not to be confused with the live
  `certman-letsencrypt`/`certman-route53-letsencrypt` solver secrets); CA-era secrets
  `ai/cert-ollama`, `argo/argocd-server-tls`, `monitoring/prometheus-grafana-cert`,
  `kube-auth/keycloak.vn.linuxguru.net-tls` (expired 2026-02-04) deleted; `kube-security`
  ns, the orphaned `tfstate-default-fuckbatz` Secret, `trivy-system`/`trivy-temp` and the
  fuckbatz lock Lease deleted. Secrets are not Terraform state, so none of it moved a
  plan. **`ai` namespace dual ownership fixed** the same day: core created it *and*
  `stacks/apps`'s `aoa_deployment` did, so destroying either stack would have taken it
  out from under the other — core released it (`state rm` **first**, then the file, so no
  plan could destroy the live namespace); apps keeps ownership.
- **How to tell you're still on track**: `tofu -chdir=stacks/<stack> plan` should be
  **empty** against a healthy cluster. Any diff is either intended work or drift — never
  silence it with a targeted apply.

