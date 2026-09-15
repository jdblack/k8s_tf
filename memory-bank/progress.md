# Progress

## What works (verified live unless noted)

- **Core platform** — Calico (tigera-operator), MetalLB (L2), external-dns
  (rfc2136 → bind9, authoritative for `vn.linuxguru.net` only), Longhorn,
  SeaweedFS + CSI, cert-manager (pinned `v1.21.1`; **`letsencrypt` DNS-01 with the
  zone pinned signs all 19 hosts** as of 2026-09-15 — no workload injects a
  private CA any more, and `~/.ssl/ca.crt` is not needed by any client; the
  `linuxguru-ca` issuer still exists but is dormant and unreferenced, expiring
  2027-08-14),
  authentik, kube-prometheus-stack + Grafana SSO, Harbor, Argo CD,
  WireGuard operator, Gateway API CRDs + shared NGF gateways.
- **Gateway/exposure model** — `gateway/expose` used by every app; certs
  auto-provisioned from the ListenerSet annotation. No hand-written
  `Certificate`s. Public/private gateway data planes pinned to
  `192.168.0.101`/`.100`.
- **IdP-first login (2026-09-15) — Harbor only; the Argo apps keep their login
  pages, deliberately.** Harbor uses its native `primary_auth_mode`. Argo CD and
  Argo Workflows were given a `gateway/redirect_route` HTTPRoute hijacking
  `Exact /` at their OIDC entrypoint, which worked until Argo CD's target lost
  its `return_url` and the callback (falling back to the base href, `/`)
  re-entered the same rule: an instant loop whose only symptoms were Chrome's
  ERR_TOO_MANY_REDIRECTS and Argo CD's `data length is less than nonce size`
  (its own `util/crypto` decrypting the just-emptied state cookie). Removed
  rather than repaired — no native auto-redirect switch exists for either app,
  so the whole thing was a facade with a sharp edge. Both hosts serve their own
  login page (`/` → 200 `text/html`) and the SSO entrypoints (`/auth/login`,
  `/oauth2/redirect?redirect=/workflows`) still hand off to authentik, so a
  bookmark still gives one click. Verified: one route destroyed in each of
  `core` and `mantle`, both stacks plan empty afterwards.
- **mantle workloads** — media (sonarr/radarr/prowlarr/bazarr/plex/qbittorrent,
  all outpost-fronted except the torrent port), blender (Samba + mDNS Bonjour
  advertiser macOS Finder needs), whisker (flow-log UI, SSO-gated),
  seaweedfs-admin (SSO-gated), Grafana/Harbor/Argo OIDC + deploy keys.
- **vaultwarden** — deployment + PVC + Service + Route53 A record, publicly
  trusted cert on a private gateway, admin panel disabled; snapshots come from
  the cluster-wide policy below (2026-09-16, per-app `backup.tf` retired). Drift
  test documented and passing (2026-09-14).
- **Longhorn snapshot policy is cluster-wide, TF-owned and audited (2026-09-16)**
  — `modules/storage/longhorn_jobs.tf` holds three jobs (`snapshot-daily` 03:00,
  `snapshot-weekly` Sun 04:00, `snapshot-monthly` 28th 05:00, all UTC, `retain: 2`)
  and the enrolment table (8 PVCs covered, 7 deliberately `skip`);
  `modules/storage/snapshot_labeler.tf` is the **only** writer of the
  `recurring-job-group.longhorn.io/*` labels, and it writes them onto the Volume
  CRs because a labelled PVC *replaces* the volume's whole group set rather than
  merging (that trap cost the vaultwarden volume its enrolment mid-migration, and
  is why no PVC in this repo carries those labels). No job may ever list the
  `default` group — Longhorn stamps every new unlabelled volume into it. Coverage
  audit + verified restore runbook: `modules/storage/disaster_recovery.md`.
- **Firewall library** — `policy` renderer + `basic_internet`,
  `limited_ingress`, `allow_api`. Media namespace locked down (2026-09-12).
  Staged/preview mechanism proven on `argo`.
- **apps stack** — ArgoCD `AppProject` + app-of-apps `Application` for `ai`
  (all three live from the external deployments dir, all Synced/Healthy on
  `library` charts: `ollama` `1.78.0`, `corsless` `0.0.26`, `llm-embedder`
  `0.0.79`).

## What's left / open

- **Namespace ingress rollout** for every namespace except `media` (see
  `activeContext.md`). This is the main thread of work.
- **Off-cluster backups: nothing has one.** No Longhorn `backupTarget` exists, so
  every snapshot (all 8 covered volumes) shares the failure domain with its
  volume, and a lost cluster takes all of it. The intended target is SeaweedFS S3
  (`s3.vn.linuxguru.net`, TLS trusted in-cluster): add a `backupTarget`/`BackupTarget`
  CR, then either flip the three snapshot jobs to `task = "backup"` or add
  parallel `backup` jobs, and update `modules/storage/disaster_recovery.md`'s
  "recovery, not backup" banner and its Gaps section when it lands.
- **Snapshot enrolment asymmetry: `sonarr-config` and `radarr-config` are
  skipped while `prowlarr-config`/`bazarr-config` get a monthly** (2026-09-16
  judgement call, not a principle — same kind of volume). One line in
  `snapshot_groups` each to fix.
- **`modules/storage/backup.yaml` is orphaned** — a hand-applied `VolumeSnapshot`
  of `sonarr-config`; no `.tf` or doc references it, and its
  `sonarr-config-snap` object still sits in `media` (14d old, `ReadyToUse`) on
  top of a now-`skip` volume. Delete both, or adopt the file properly.
- **Plex plugin volume**: `media/pms-config-plex-plex-media-server-0` is a
  VCT-driven volume holding the Plex plugin/config tree; switching plex to a
  `configExistingClaim` (one PVC, longhorn-backed) would make it snapshottable
  like the rest instead of `skip`.
- **`signups_allowed` must go back to `false`** after any first-account
  bootstrap (`stacks/mantle/vaultwarden.tf`); see the vaultwarden README.
- ~~**Core-apply landmine**~~ **FIXED 2026-09-16.** Was: a core apply aborting
  with `Provider produced inconsistent final plan ... .spec[0].egress[1].to:
  block count changed from 1 to 2`, triggered by **any pending change in a module
  listed in the caller's `depends_on`** — `module.cert_man` fired it just as
  easily as `module.storage` — because a module-level `depends_on` covers every
  resource *and data source* in the module: the `kubernetes` Endpoints read
  inside authentik's `allow_api` (and cert_man's `basic_internet`) was deferred
  to apply time, so the policy planned a *guessed* `to` block count (1 =
  ClusterIP) while the apply read the real 2 (ClusterIP + endpoint). Evidence of
  the old behaviour: `/tmp/core.apply.log` (2026-09-15 01:14, `Plan: 0 to add, 5
  to change`, cert_man only, storage clean) + `/tmp/core-apply.txt` +
  `/tmp/relabel.txt` (2026-09-16).
  **Fix:** the read moved to the stack root — `stacks/core/core.tf` declares
  `data.kubernetes_endpoints_v1.kubernetes` + `local.api_peer_ips` and passes it
  down through a new optional `api_peer_ips` variable on `allow_api`,
  `basic_internet`, `modules/auth/authentik/core` and `modules/cert_manager`.
  Setting it disables the module's own counted read (`count = ... &&
  var.api_peer_ips == null`), so no `depends_on` can defer it; the `null` default
  leaves mantle's media call untouched. Hardcoding control-plane IPs was
  considered and rejected — see `.clinedocs/calico-netpols.md`.
  **Verified:** core plan = No changes (identical peers, netpol UIDs unchanged,
  no recreate); a deliberate pending change in `module.storage` then planned
  `1 to change` and **applied clean** (this is the case that used to abort),
  with 0 `will be read during apply` lines; reverted → No changes; mantle =
  No changes with media's in-module read still working.
  **Residual:** a *new* module-level `depends_on` on a caller of a firewall with
  `allow_to_k8sapi = true` (argo today — it has none) re-arms this; the invariant
  is written up in `.clinedocs/calico-netpols.md`.
- **vaultwarden has nothing to scrape** — 1.37.3 dropped its metrics build
  feature (no `/metrics`, no `PROMETHEUS_ENABLED`, only `GET /alive`), so the
  module ships no ServiceMonitor. Re-check upstream; if it returns, add
  `monitoring.tf` and add `monitoring` to the ingress guest list in
  `modules/vaultwarden/security.tf`.
- **Longhorn Grafana dashboard** not imported.
- **external-dns HTTPRoute-annotation publishing** unexplained for `.vn` names.
- ~~**Let's Encrypt for the remaining `.vn` hosts.**~~ **DONE 2026-09-15: all 19
  hosts are on `letsencrypt`** (16 declared here + the 3 `ai` hosts from the
  external repo) and every CA injection was deleted in the same
  apply as the last four flips (`auth.vn`, `harbor`, `grafana`, `argo-wf`). See
  `activeContext.md` for the verification evidence (SSO hand-offs, in-cluster
  trust probe, cluster-wide CA sweep).
- **Retire the CA** (the migration's last step) — **deliberately deferred as of
  2026-09-15: the private CA is kept on purpose, in case it's wanted back, so
  don't "finish" this without asking.** The issuer plumbing was collapsed onto
  `cert_authorities.default` the same day, so the CA is now one `private` key that
  nothing names. When it does happen: drop the `linuxguru-ca`
  ClusterIssuer + the `kube-certificates/linuxguru-ca` Secret + the
  `default/linuxguru-ca` ConfigMap + the module's `ca_certfile`/`ca_keyfile`
  `file()` inputs, then `~/.ssl/ca.crt` and the node trust store in
  `initial_setup.yml` (k8s repo). Nothing is broken while it lingers — but
  `~/.ssl/ca.*` must keep existing or `tofu plan` fails.
- **Nothing scrapes cert-manager.** No `ServiceMonitor`, no expiry
  `PrometheusRule`, so a failed renewal stays invisible until the cert expires
  (~30 days of slack at 2/3 lifetime). Cheap win: ServiceMonitor on
  `kube-certificates/cert-manager:9402` + a
  `certmanager_certificate_expiration_timestamp_seconds < 21d` alert.
- **`corsless` / `llm-embedder` are still dead apps** — no longer for TLS
  reasons. Their Helm repos (`linuxguru/corsless-helm`, `linuxguru/llm-embedder-chart`)
  return `404: repository not found` from Harbor, so the charts were never pushed
  or were removed. Only `ollama` is live from that external app-of-apps dir.
  **RESOLVED 2026-09-15**: it was a registry split-brain — Argo, the values and
  TF all named Harbor project `linuxguru` while the `build` scripts pushed to
  `library`, and `robot$jblack` can only push to `library`. Everything is
  repointed at `library`, helm's credential store is seeded, both charts render
  `extraObjects`, and `library/corsless-helm:0.0.26` is published. `corsless` is
  **verified serving** (stock-trust TLS, app answers; cert re-issued from the old
  CA to `letsencrypt`). **`llm-embedder` is live *and* correct**: Argo
  Synced/Healthy on `library/llm-embedder-chart:0.0.79` +
  `library/llm-embedder:v0.0.79`, 5/5 pods on the new tag after a clean rollout,
  `/health` answers through the gateway, and `/embed` → `200` with a 1024-dim
  vector (the `retrival.query` typo that 500'd every call is gone from the
  *shipped* image — the source fix had to be republished to count). The TF
  `argocd_repository.devops_helm` repoint at `/library` is applied and both stacks
  plan `No changes`. See `activeContext.md` for the full bug chain.
- ~~Orphan ClusterIssuer `letsencrypt-http`~~ — HTTP-01/ingress-nginx leftover,
  in no `.tf` and referenced by no Certificate. **Deleted 2026-09-15**, along with
  its `letsencrypt-http-key` account key.
- **Whisker UI through the proxy** — unconfirmed.
- **authentik group membership** is hand-managed → a from-scratch rebuild needs
  members re-added by hand.
- **One-time, hand-run per-app config** that a rebuild must redo:
  arr apps `AuthenticationMethod = External`; qBittorrent pod-CIDR WebUI
  whitelist + hard pod kill; vaultwarden first-account bootstrap
  (`signups_allowed = true` → register → back to `false`).
- **Chart pinning debt** — Harbor, external-dns,
  snapshot-controller, metrics-server, prometheus-smartctl-exporter, argo-cd,
  argo-events all float today, as does plex (whose chart "repository" is a
  `raw.githubusercontent.com` gh-pages path — pinning it means checking the
  chart still resolves, not just picking a version).
- **Optional**: a `posture` wrapper so a namespace states egress+ingress in one
  call instead of 2-4 module calls (deferred until after the rollout).
- **Accepted risks**: `goldmane:7443` readable by any pod (unfixable from TF);
  media NodePort soft spot (`nodeIP:nodePort` bypass); `ollama` has no auth in
  front of it.

## Evolution of decisions worth knowing

- `allow_ingress` → renamed `limited_ingress` (2026-09) because the old name
  read like a blanket allow when it is a lockdown with a guest list. Docs/paths
  only — no resources moved, so no create/destroy.
- `namespace_only` is gone — replaced by `limited_ingress` with a one-namespace
  guest list, typed instead of `kubectl_manifest`.
- ntfy alerting was added and then removed (2026-09); Alertmanager runs stock
  `null`.
- `.vn` hosts moved to Let's Encrypt on demand: DNS-01 needs no inbound
  reachability and no new Route53 zone. At the time that was driven by a per-app
  `cert_issuers` override (`modules/media`) plus a module-level
  `cert_issuer`/`cert_issuers` pair — **both override maps were deleted
  2026-09-15**: a host now moves by changing `cert_authorities.default`, and a
  genuine per-host exception would be new plumbing, not a map.
  2026-09-15 went from one host (`sonarr`) to **12 of 17 certs**, with
  `modules/media`'s default flipped to the public issuer and a 9-host batch
  applied in a single pass — proving the "one host at a time" caution was
  unnecessarily conservative for leaf-only hosts. The same day finished the job
  (17 of 17): the last four flips had to ride in the **same apply** as the
  deletions of their CA trust material, because the *replacing* knobs (Grafana's
  `SSL_CERT_FILE`, Workflows' bundle subPath mount) break their app's SSO if
  separated from the flip in either direction. The `ca_name` split that was
  planned for that turned out to be unnecessary — deleting the wiring in the same
  apply is what removes the coupling.
- The `modules/security/trivy` module was removed 2026-09, leaving three empty
  namespace shells (nothing but `kube-root-ca.crt` + the `default` ServiceAccount):
  `trivy-system` and `trivy-temp` unmanaged, `kube-security` still declared in
  `stacks/mantle/security.tf` for no reason. All three deleted 2026-09-15 (the
  declared one via `apply`), along with the orphaned `tfstate-default-fuckbatz`
  state Secret and its `lock-tfstate-default-fuckbatz` Lease.
- **`.terraform` caches trimmed, 2.5 GB → 1.5 GB (2026-09-15).** Only provably
  dead things were deleted — provider versions absent from the stack's
  `.terraform.lock.hcl`, and module dirs no enabled `.tf` references. That caught
  every stale duplicate left by version bumps (three old `argoproj-labs/argocd`
  versions in mantle, `helm` 3.0.2/3.1.0, `kubernetes` 2.35.1, `kubectl` 1.18.0,
  `random` 3.7.2, plus core's `loafoe/htpasswd` and `goharbor/harbor`, which no
  config requires any more), both cached `keycloak/keycloak` versions (dead
  provider for a retired app), and `stacks/apps/.terraform/modules/fuckbatz_website`
  (81 MB) + `ngoc_website`, orphaned since those two modules were parked as
  `.tf.disabled`. All three stacks still plan `No changes` afterwards. The
  remaining 1.5 GB is live and pinned — a full wipe would just re-download it, so
  don't bother unless disk pressure demands it.
- WordPress deployments in `stacks/apps` were disabled when the cluster moved
  from ingress-nginx to Gateway API (they expect `ingress_class`); reviving them
  means porting to `gateway/expose` and passing `cert_authorities.default`
  (`letsencrypt`, DNS-01 — `letsencrypt-http` is long gone and `linuxguru-ca` is
  dormant).
- **One of the two wordpress modules was deleted outright 2026-09-15**, not just
  parked: `notbatz.com_website.tf.disabled` (module `fuckbatz_website`, namespace
  `fuckbatz`, `www.notbatz.com`/`notbatz.com`). `notbatz.com` has **no Route53
  zone in this account** — only `linuxguru.net` and `emtho.com` are hosted here —
  so it could never have resolved, and its config was dead on arrival anyway
  (dead issuer, dead ingress class). Its state Secret, lock Lease, 81 MB module
  cache and `.terraform/modules/modules.json` entry all went with it. The sibling
  `ngoc_website.tf.disabled` (`www.emtho.com`) is deliberately **kept**: that zone
  does exist here, so the file is the only record of the site's definition.

- Harbor's `library` project is **not TF-managed, on purpose** (2026-09-15): it's
  Harbor's *default* project, and the only thing TF needs from it is the name, to
  build the OCI URL in `modules/argo/mantle/argo-cd/repositories.tf`. Parameterizing
  it would add a knob whose one legal value is "the default", so the dead
  `argocd_devops.harbor_project` tfvars key was deleted instead of wired. Same call
  for `argocd_devops.repo_name` (the module hardcodes the display name). Consequence:
  a from-scratch rebuild still needs `library` to exist — which it does, by default,
  so nothing to do; what it can't recreate is the hand-made `robot$jblack` permission
  on it.

- **How the IdP-first attempt went, and why it's gone (2026-09-15; reversed the
  same day).** Harbor's `primary_auth_mode` is the only *native* lever, and the
  UI acts on it **client-side**, so `curl /` still answers 200 — verify via
  `/api/v2.0/systeminfo` (`primary_auth_mode:true`), *not* the `harbor-core` cm,
  which never carries that key (an empty cm value is a false alarm). Argo CD's
  nearest native lever is `admin.enabled: "false"` in `argocd-cm`; rejected,
  because the mantle stack's `argocd` provider authenticates as `admin`, so it
  would break every later apply (the real fix is a named `iac` apiKey account +
  RBAC `role:admin` + token, plus no UI break-glass — deferred as its own
  change). Workflows has no lever at all: its login page is hardcoded and
  `--auth-mode=sso` only means no password form. Faking it at the gateway was
  possible (`redirect_route`: one redirect-only `Exact /` rule, no `backendRefs`,
  so it outranks the app's own `PathPrefix /` route by match specificity) and it
  did work — but it pushed another program's OIDC callback semantics into a
  routing string, where no `plan` can see them break, and that is exactly how it
  looped. Module and both call sites deleted. If it is ever rebuilt: the match
  type must be `Exact` (`PathExact` fails CRD validation — not a Gateway API
  type), the route needs a distinct name (`<name>-sso-redirect`; the app already
  owns one named `<name>`), and `replaceFullPath` **must** carry the app's
  post-login target, because a callback without one falls back to `/` and closes
  the loop.
- **State lives in the Kubernetes backend** (`kube-system`, `secret_suffix =
  core|mantle|deployment`), so an interrupted command leaves no local lock file —
  it leaves `tfstate-default-<stack>-lock`, and a local `ls` for
  `*.tfstate.lock.info` proves nothing. Clear it with
  `tofu -chdir=stacks/<stack> force-unlock -force <ID>` once `ps` shows no live
  `tofu` client (an interrupted `plan` holds it with `OperationTypePlan` and has
  written no state).

## How to tell you're still on track

`tofu -chdir=stacks/<stack> plan` should be **empty** against a healthy cluster.
Any diff is either intended work or drift — never silence it with a targeted
apply.
