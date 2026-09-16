# Progress

## What works (verified live unless noted)

- **Core platform** — Calico (tigera-operator), MetalLB (L2), external-dns
  (rfc2136 → bind9, authoritative for `vn.linuxguru.net` only), Longhorn, SeaweedFS +
  CSI, cert-manager (pinned `v1.21.2`; **`letsencrypt` DNS-01 with the zone pinned signs
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
- **There is no network-policy layer, on purpose (deleted 2026-09-16).** The `firewalls/`
  library (`policy` renderer + `basic_egress` + `limited_ingress`) and every per-app
  `security.tf` were removed, so every workload reaches every other one. **One exception:**
  `modules/network/whisker/tier.tf` — 3 Calico CRs at `spec.tier: calico-system` that are a
  prerequisite for whisker, not a restriction on it. Conserved invariants: `.clinedocs/calico-netpols.md`.
- **`calico-system` is policed by a Calico *tier*, and whisker is fixed (2026-09-16).**
  tigera-operator `v3.32.2` moved its own rules into tier `calico-system` (`order: 100`,
  `defaultAction: Deny`), whose end-of-tier DROP pre-empts tier `default` — where a k8s
  NetworkPolicy compiles — so whisker's UI died (`code=000`) with the
  gateway healthy. Fix: `modules/network/whisker/tier.tf`, three pod-scoped Calico
  `NetworkPolicy` CRs at `spec.tier: calico-system`, `order: 10` (outpost egress; gateway →
  outpost:9000; outpost → whisker:8081). **Verified live**: `whisker.<domain>/` → `302` to
  the outpost → authentik's flow page **HTTP 200** with `ak-flow-executor` in the body; the
  outpost's DNS timeouts went to 0; and flow records name `whisker-outpost-ingress-tier` the
  **deciding** policy for gateway→outpost:9000 (the same dataset still holds the pre-fix
  `Deny`, so it is before/after, not one sample). Two things worth carrying: an in-tier CR
  needs an explicit `order` to beat the operator's unset-order deny-alls
  (`.clinedocs/calico-netpols.md`), and **the outpost does not recover on its own** — its
  failed config fetches back off exponentially and it never opens `:9000` again, so the
  gateway serves `502` (upstream RST, policy already passing) until
  `kubectl rollout restart deploy/whisker-auth`. It first landed **by hand** (`kubectl apply` of
  the rendered CRs) because mantle's apply was blocked by an unrelated authentik lookup; the
  CRs are now **imported into state** and applied by mantle (`12 added / 8 changed / 0
  destroyed`, post-apply plan `No changes`).
- **Core-apply landmine (2026-09-16) — moot since the firewall layer was deleted; kept
  because the mechanism is generic.** Was: a core apply aborting with
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
  (2026-09-15 01:14), `/tmp/core-apply.txt`, `/tmp/relabel.txt`. **Now moot:** the read, the
  `api_peer_ips` plumbing and the policies themselves were deleted with the firewall layer, so
  nothing here re-arms it. Keep the lesson for any provider-deferred read inside a module under
  a caller's `depends_on`; invariant in `.clinedocs/calico-netpols.md`.
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
- **Authentik proxy-outpost consolidation (2026-09-16).**
  `auth/authentik/{proxy_app,outpost}` are one module — `auth/authentik/proxy_outpost` — and
  media/whisker/seaweedfs_admin each make **one** call instead of two. The outpost's API token
  no longer crosses a module boundary (the Secret's `AUTHENTIK_TOKEN` is built in-module) and
  `outpost_token` is gone as an output; `core_url`/`browser_url` are derived from `domain` +
  `core_namespace` rather than passed by every caller. State carries over via 12 `moved` blocks
  (4 per caller — a module-level move is refused when the destination module already holds
  resources; see `activeContext.md`). **mantle applied** (`0 added / 0 changed / 0 destroyed`,
  moves only; post-apply plan `No changes`; the three outposts were not rolled — deployment
  ages still 09-09/09-12, pods 6d+). The 12 `moved` blocks stay for one commit cycle, then go.
  **core applied** `0 added / 0 changed / 2 destroyed` (the unreferenced
  `random_password.deploy_key`/`.database`); post-apply plan `No changes`.
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

## The 2026-09-16 batch — written, then applied

**Applied 2026-09-16** (`tofu -chdir=stacks/core apply /tmp/core-pinned.tfplan` → 0 added,
17 changed, 2 destroyed; post-apply `plan` → `No changes`; mantle was already 0/10/0, apps
clean). Kept here as the rationale record. All in-place-only; all three stacks `validate`.

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
- **Every chart release is version-pinned (2026-09-16); the last three floats were pinned
  before the batch was applied.** `modules/network/calico.tf`, `modules/network/external_dns.tf`
  and `modules/monitoring/smartctl/helm.tf` had **no `version` argument**, and the *unpinned*
  core plan proves what that costs: three concrete ride-along upgrades, riding on nothing
  but `timeout` bumps — tigera-operator `v3.31.2` → `v3.32.2`, external-dns `1.21.1` →
  `1.22.0`, smartctl `0.16.0` → `0.17.1`. Pinned to the **deployed** versions as
  `helm_calico_version`, `helm_external_dns_version` (following `helm_metallb_version`'s
  shape) and smartctl's `helm_version` → the pinned plan carried **zero** top-level `version`
  diffs, and the applied diff was exactly the 17 `timeout` bumps + the 2 gateway `values`
  (VIP unpin) + the 2 inert `random_*` destroys. Verified nothing moved: `helm list` →
  tigera-operator-v3.31.2, external-dns-1.21.1, prometheus-smartctl-exporter-0.16.0, and
  `calico-node` still `quay.io/calico/node:v3.31.2`.
- **The remaining six were pinned too, same day** — harbor (`modules/harbor/core/main.tf`,
  `helm_version`), metrics-server (`modules/monitoring/metrics_server/metrics_server.tf`;
  that module keeps its vars inline — it has no `variables.tf`), snapshot-controller
  (`modules/storage/snapshots.tf` + `helm_snapshot_controller_version`),
  argo-cd (`modules/argo/core/argo-cd/helm.tf`), mantle's
  `modules/argo/mantle/argo-events/helm.tf`, and plex (`modules/media/plex/main.tf`). All
  pinned to the deployed chart: `1.19.2`, `3.14.0`, `5.2.0`, `9.2.4`, `2.4.19`, `1.9.0`.
  **This required no apply:** the provider records `version` in state for every release
  whether or not config sets it, so core re-planned `No changes` and mantle's plex/
  argo-events hunks are byte-identical pre/post pin. Today's no-op, tomorrow's protection:
  harbor, metrics-server, snapshot-controller and plex are at upstream-latest right now;
  argo-cd and argo-events were **not** — both were upgraded 2026-09-16 (next entry).
- **`stacks/mantle`'s 0/10/0 hygiene batch was applied too, later the same day** (exit 0,
  `Apply complete! 0 added, 10 changed, 0 destroyed`; post-apply plan `No changes`). Real
  deltas: `+ runAsGroup: 1000` on the bazarr/radarr/sonarr charts (the rest of each `values`
  hunk was `jsonencode`→`yamlencode` re-render noise — `/media` is still mounted in config
  *and* in the live sonarr pod), qbittorrent pinned to
  `lscr.io/linuxserver/qbittorrent:5.2.3_v2.0.14-ls475` + `IfNotPresent` + `strategy:
  Recreate`, blender's samba pinned to `dockurr/samba:4.23.10` (was a floating `:latest`),
  and qbittorrent's torrent Service clearing `loadBalancerIP` (**`.105` retained** — the
  unpin behaviour re-verified on a third Service). **Every chart version unmoved:** bazarr
  `2.3.0`, ngf `2.6.7`, plex `1.9.0`, prowlarr `3.8.2`, radarr `3.6.1`, sonarr `2.2.2`,
  argo-cd `9.2.4`, argo-events `2.4.19`, argo-wf `0.46.4` (`helm list`). The 5-minute
  near-miss on `ngf` is the next entry.
- **Reading chart drift — three sources, don't confuse them.** Config: the awk audit below.
  Deployed: `tofu -chdir=stacks/<s> state show '<addr>' | grep '^ *version'` or `helm list
  -A`. Upstream: `helm show chart <chart> --repo <repo>` with **no** `--version`.
  Audit (validated and negative-tested — the crude `grep -L version` I first wrote
  false-positives on files that merely *mention* `helm_release`):
  `for f in $(grep -rl 'resource "helm_release"' modules/ stacks/ --include='*.tf'); do awk
  -v F="$f" '/^resource "helm_release"/ { if (ln && !found) print F":"ln" MISSING"; ln=NR;
  found=0; next } ln && !found && /^  version[[:space:]]*=/ { found=1 } ln && /^}/ { if
  (!found) print F":"ln" MISSING"; ln=0 } END { if (ln && !found) print F":"ln" MISSING" }'
  "$f"; done` → clean as of 2026-09-16.
  **Traps in reading a plan for this.** (a) Only a `version` line indented **6 spaces** is
  the top-level attribute, i.e. a real upgrade; every release the plan touches also emits
  `~ version` / `~ app_version` at 8+ spaces inside its `metadata` block (20 of them in this
  batch), so a naive `grep version` on a plan invents upgrades that don't exist. (b) A
  planned value that equals state prints **no line at all**, so "no version line" ≠ "no
  unversioned chart" — it can just as well mean "chart-latest resolved equal to what is
  installed", which is why the four releases already on upstream-latest showed nothing.
  **Not understood — don't assume the risk is gone.** argo-cd (upstream `10.9.1`) and
  argo-events (`2.4.27`) were unversioned and were being updated in-place in those same
  plans, yet planned **no** `version` change, while calico/external-dns/smartctl did. Two of
  the six sat on newer upstream charts and did not move: luck, not a property. An unversioned
  chart is a latent, non-deterministic upgrade; the pin is what makes it deterministic.
  Deployed vs upstream this date: tigera `v3.31.2`/`v3.32.2`, ext-dns `1.21.1`/`1.22.0`,
  smartctl `0.16.0`/`0.17.1`, argo-cd `9.2.4`/`10.9.1`, argo-events `2.4.19`/`2.4.27`;
  everything else already latest.
- **First upgrade batch off the pins — five releases, one apply each (2026-09-16).** Final
  versions: cert-manager `v1.21.1`→`v1.21.2`, argo-events `2.4.19`→`2.4.27` (mantle — the
  only one of the five), external-dns `1.21.1`→`1.22.0`, kube-prometheus-stack
  `90.1.1`→`91.4.1`, argo-cd `9.2.4`→`10.9.1`. Each was applied on its own so a failure had
  one suspect (cheap: 4 of the 5 live in `core` but each plan touched a single
  `helm_release`, so no `-target` was ever needed), every plan was read for the 6-space
  `version` line only, and both stacks re-planned **No changes** afterwards. Verified live,
  not assumed: all three cert-manager pods on `v1.21.2` + every Certificate `Ready`;
  argo-events controller on app `v1.9.11`; extdns pod on `v0.22.0`; prometheus operator
  `v0.94.0` with 59/59 targets up and Grafana `13.2.2` whose `/login/generic_oauth` → 302 to
  authentik with our `client_id`/scopes/`redirect_uri`; argo-cd app `v3.5.3` with all four
  Applications Synced+Healthy and `/auth/login` → 303 to authentik. Logs:
  `/tmp/core-*.apply.txt`, `/tmp/mantle-argoevents.apply.txt`.
- **The one upgrade that needed a values change, not just a bump: external-dns 1.22.0.**
  Chart 1.22.0 made `policy` **required** (it used to default to `upsert-only`) and we never
  set it, so a bump-only release would have failed schema validation —
  `helm template … --version 1.22.0` → `at '/policy': got null, want string`. Fixed with
  `policy = "upsert-only"` in `modules/network/charts.tf`, which renders an args list
  **identical** to the 1.21.1 render (that chart emitted `--policy=upsert-only` implicitly),
  making the upgrade image-only (`v0.21.0`→`v0.22.0`). Pre-existing, not a regression: it
  warns `--rfc2136-axfr is not set: … --policy=upsert-only will never update or delete
  them` — so external-dns only ever *creates* records, and an A-record IP change will not
  follow. Fixing that needs AXFR + `policy = "sync"`, separately.
- **argo-cd 10.x turns on six ingress NetworkPolicies by default — disabled here.** `10.0.0`
  added per-component netpols gated by `global.networkPolicy.create`, **true** by default;
  with it on, 10.9.1 renders 6 objects 9.2.4 did not (server = `ingress: - {}` allow-all;
  controller/notifications allow `metrics` from any namespace; repo-server allows only the
  four in-namespace components; dex and redis are allow-lists). `argo` had **no** netpols and
  the repo's were TF-owned (`modules/network/firewalls`, itself deleted 2026-09-16), so the
  default would have been a network-posture change riding along with a version bump. Set
  `global.networkPolicy.create = false` in `modules/argo/core/argo-cd/locals.tf`; with it off
  10.9.1 renders **exactly 54 objects — the same set as 9.2.4**, which is what made this a
  pure version bump. Enabling them later is cheap and low-risk: nothing scrapes Argo metrics
  (no ServiceMonitor/PodMonitor in `argo`, no argo targets in Prometheus).
- **`finalizers` in argo-cd's values was dead config — deleted, not re-homed.** The chart has
  no top-level `finalizers` value in 9.2.4 *or* 10.9.1: rendering with it set is
  byte-identical to rendering without it, and a grep of the whole chart finds `finalizers`
  only as an RBAC *verb*. So no Application ever carried
  `resources-finalizer.argocd.argoproj.io`, despite the config implying it. Doing it properly
  means putting the finalizer on the `aoa_deployment` Application — which **changes destroy
  semantics** (tearing down `apps` would then cascade-delete everything Argo manages) — so
  it is a decision to make deliberately, not a cleanup.
- **cert-manager `v1.21.2` fixes exactly our shape of bug.** Its `helm show values` is
  byte-identical to `v1.21.1`, and the notes include *"De-duplicate dnsNames when multiple
  Gateway/ListenerSet listeners share a Secret"* — precisely our model, since `gateway-shim`
  derives per-listener Certificates from the ListenerSet annotations — plus webhook panics on
  malformed AdmissionReviews and ACME renewal-window / HTTP-01-cleanup fixes.


### NGF's cert-generator hook vs media's API carve-out — diagnosed 2026-09-16 (the fix is gone)

**Superseded the same day:** the whole policy layer was deleted (see the deletion section
above), so the fix below no longer exists and this exact deadlock cannot recur. Kept for the
generic trap — **a Helm hook Job's pods carry only the Job controller's labels**, so a
pod-selector-based allow-list never matches them, and a `wait`-ing release turns that into a
five-minute stall instead of a visible failure.

- **Symptom:** the `ngf` helm release in the mantle apply sat at `Still modifying...
  [id=ngf]` for five straight minutes (`helm status` → `pending-upgrade`, revision 6), while
  four `ngf-nginx-gateway-fabric-cert-generator-*` pods sat `Error`.
- **Cause (from the hook's own log):** `error creating secrets: error getting secret
  media/ngf-server-tls: failed to get server groups: Get "https://10.96.0.1:443/api": dial
  tcp 10.96.0.1:443: i/o timeout`. media's `basic_internet` is `allow_to_k8sapi = false` and
  its `allow_api` carve-out selects `app.kubernetes.io/name = nginx-gateway-fabric` — but a
  **Job's pods carry only the Job controller's labels** (`job-name`,
  `batch.kubernetes.io/job-name`, `controller-uid`) and none of the chart's, so the
  `pre-install`/`pre-upgrade` hook had no API egress, exhausted `backoffLimit: 6`, and
  helm's `wait` burned the release's whole `timeout` — two timeouts waiting on one deadlock.
  The chart has no values for it: NGF 2.6.7's `certGenerator` offers only
  `enable|annotations|serverTLSSecretName|agentTLSSecretName|overwrite`.
- **Why now:** the media netpols landed 2026-09-09, the last NGF upgrade before this was
  2026-08-31 — so this batch was the first NGF upgrade with the firewall in place. Only
  `media` is exposed: `kube-network` has **no** NetworkPolicies at all, which is why core's
  two gateways (and their own hooks) upgraded cleanly the same morning; authentik's
  `allow_api` is worker-scoped and has no chart hook.
- **Fix:** a second pod-scoped policy in `modules/media/security.tf`
  (`policy_name = "allow-api-egress-certgen"`, `pod_selector = { "job-name" =
  module.gateway.cert_generator_job_name }`) — one NetworkPolicy cannot OR two selectors —
  plus a new `cert_generator_job_name` output in `modules/network/gateway/outputs.tf` that
  derives the Job name from `release_name` (the chart's
  `<release>-nginx-gateway-fabric-cert-generator`) instead of a hardcoded literal.
- **Recovery, since the apply was mid-flight:** the policy was created by hand from the live
  `allow-api-egress` JSON (5th retry pod then succeeded, job completed, helm finished,
  `Apply complete!`, exit 0 — the Job is gone because helm deletes a succeeded hook), then
  adopted with `tofu import 'module.media.module.allow_api_cert_generator.module.policy.
  kubernetes_network_policy_v1.this' media/allow-api-egress-certgen` after stripping the
  stopgap `managed-by` label so live == rendered; mantle then planned `No changes`. **Superseded
  2026-09-16:** the policy and the whole layer were deleted, so there is no hand-made object left
  to avoid re-creating.
- **Verified after the fact (no upgrade needed):** a throwaway `curlimages/curl` pod labeled
  with only `job-name=ngf-nginx-gateway-fabric-cert-generator` got `http_code=403` from
  `https://10.96.0.1:443/api` in under 6 s, while the same pod without matching labels still
  timed out (`curl: (28) Connection timed out after 8001 ms`) — as intended, the *union*
  moved (hook pods only) and the namespace-wide API deny is intact.
- **The doc had asserted the opposite:** `modules/network/firewalls/allow_api/README.md`
  claimed the selector "covers the controller deployment and the chart's cert-generator
  job". Corrected, with a new "Hook Jobs need their own selector" section; the media README
  posture bullet updated too.

## The 2026-09-16 second batch — the eight-release backlog, one apply each

**All applied and verified the same day** (each its own apply, so a failure had one
suspect); `core` and `mantle` both end at **`No changes`** and `tofu fmt -recursive -check`
is clean. Final versions: smartctl `0.16.0`→`0.17.1`, bazarr `2.3.0`→`2.3.1`, sonarr
`2.2.2`→`2.2.3`, prowlarr `3.8.2`→`3.8.4`, radarr `3.6.1`→`3.6.4`, tigera-operator
`v3.31.2`→`v3.32.2`, argo-workflows `0.46.4`→`2.0.6` (app `v3.7.7`→`v4.1.3`), authentik
`2025.10.3`→`2026.8.2` (+ provider `2025.10.1`→`2026.8.0`).

**Mechanical tier — cheap by construction.** smartctl renders a byte-identical DaemonSet
(same image `v0.14.0`; the six pods kept their ages right through the apply, which is the
proof). The four arr bumps are image-tag-only: `helm show values` byte-identical and object
sets identical for each, so the only delta is the tag (`bazarr:1.6.1`, `prowlarr:2.6.4`,
`radarr:6.4.4`). **sonarr is the exception** — its module pins `image.tag = "4"` with
`pullPolicy: Always`, so the chart's `4.0.20` default is unused and its pod does not roll at
all. Each app answers `302` through the outpost afterwards.

**Trap — an empty-vs-empty `diff` reads as "identical".** Twice in this batch a
`sed -n '/# Source: <wrong path>/,/^---$/p'` extraction yielded two empty streams and `diff`
exited 0, i.e. a vacuous "server Deployment unchanged" pass that would have shipped an
unverified upgrade. `/tmp/authdiff.sh` (extract by `# Source:`, refuse when either side is
empty) is the fix. Same family: **`helm show crds` prints nothing for a chart that has no
`crds/`** — that is not evidence either, and it is what made calico's 3.32 layout change
look like a mystery rather than an answer.

**Calico `v3.32.2` — the chart deleted its whole `crds/` directory.** v3.31.2 shipped 9
files / 32 CRDs; v3.32.2 ships none, because helm never upgrades or deletes `crds/`
resources, so upstream moved them to a separate `crd.projectcalico.org.v1` chart and its
README now says to apply/upgrade the **CRDs before** the operator chart. The rendered
templates are otherwise identical (same 11 objects; operator image `v1.40.2`→`v1.42.6`, plus
new `--bootstrapCRDs` RBAC). Handled in `modules/network/calico.tf` with a `terraform_data` +
`local-exec` bootstrap — the same shape as `api_gateway_config.tf`, version keyed by
`triggers_replace` — and `helm_release.calico` now `depends_on` it. Three things that cost
time, worth not re-learning:
* the first attempt **failed safely**: `kubectl apply --server-side` refused
  `.spec.versions` and one annotation because field manager `terraform-provider-helm` owned
  them, so `--force-conflicts` is required — and the failure aborted the apply *before* the
  helm upgrade (calico stayed `v3.31.2`, every `tigerastatus` True),
* `--force-conflicts` is only defensible after proving **no served version is dropped**:
  `/tmp/crd-version-check.py` checks that per CRD, and the answer was 0 dropped / 0 added
  (v3.32.2 only *adds* `clusternetworkpolicies` + `istios.operator.tigera.io`, and the
  ANP/BANP CRDs simply stay behind because apply never deletes),
* these CRDs carry **no** helm ownership metadata (`meta.helm.sh/release-name` empty), so
  unlike argo-wf's they were never at risk of deletion.
Verified after: operator `v1.42.6`, `calico-node` **6/6 on `quay.io/calico/node:v3.32.2`**,
all six `tigerastatus` True, nodes Ready, the node CNI config rewritten to
`cniVersion: "1.0.0"` (containerd 2.2.1 ≥ 1.6 — the release-note caveat), and pod→Service,
pod→pod-IP and external egress all answering. (One "failed" connectivity probe was my own
wrong port: the smartctl Service is `80 → targetPort http`; 9633 is the pod's.)

**argo-workflows `2.0.6` — the CRDs left the release manifest.** 0.46.4 rendered its 8
`*.argoproj.io` CRDs as ordinary templated resources (helm-owned: verified
`meta.helm.sh/release-name=argo-wf`), and 1.x/2.x replaced that with a
`pre-install,pre-upgrade` hook Job (`argo-workflows-crdinstaller:v4.1.3` + SA/ClusterRole/
ClusterRoleBinding, `hook-weight: -10`, `before-hook-creation,hook-succeeded`). **Helm
deletes resources that leave a manifest**, so the upgrade could have taken all 8 CRDs with
it — so they were snapshotted and annotated `helm.sh/resource-policy: keep` first. That
worked: all 8 keep their original `creationTimestamp`, and `managedFields` shows a
`kubectl op=Apply` entry at the upgrade moment, i.e. the hook refreshed their schema without
a delete. Blast radius was genuinely low (0 Argo CRs existed), which is why this was
attempted rather than deferred. With our values, the rendered server/controller Deployments
differ only in image tag, chart labels, `checksum/cm` and a new `strategy: Recreate` on the
controller; the SSO surface is untouched, and the server ClusterRole still restricts secrets
to `resourceNames=[argo-wf-sso-creds, argo-wf-ui-admin.service-account-token]` — so
**`server.sso.rbac.secretWhitelist` is *not* dead config** (it renders into
`server-cluster-roles.yaml`, which is why grepping a render for the literal key finds
nothing). Verified: `argocli:v4.1.3` / `workflow-controller:v4.1.3`, UI `/` 200, SSO entry
302 → `auth.vn/application/o/authorize/?client_id=argo-wf`, and mantle `No changes`.

**authentik `2026.8.2` — the recorded "crashes at startup" finally has a cause, and it was
never the listen address.** authentik **refuses major version skips**: 2025.10.3 → 2026.8.2
dies inside `run_migrations()` with
`[error] Major version skips are not allowed. ...?from=2025.10.3&to=2026.8.2`, and the
container surfaces only `the server has exited unexpectedly` (`src/server/mod.rs:245`) —
which is exactly what this repo has carried as a pin comment for months. Migrations never ran
(the check aborts before them), the old pods served throughout (a failed helm upgrade never
cuts the Deployment over), and there is both a full logical backup
(`/tmp/authentik-db-20260916-150454.sql`, 138 MB, 187 tables) and the Longhorn snapshots.
So it is **four applies, one release each**: `2025.12.4` → `2026.2.3` → `2026.5.6` →
`2026.8.2` (helm revisions 12–15; revision 11 is the failed skip attempt). Each step was
verified as it went (image-only render deltas, migrations clean, `auth.vn` login flow 200,
Grafana SSO 302, outposts healthy). Pre-flight that earned its keep: the DB had **no
duplicate group names** (the 2025.12 migration *fails loudly* on those) and
`PGDATA`/`data` mountPath are unchanged across the postgres subchart bump (16.7.27 →
18.8.17), so the existing PVC is adopted. Note the bitnami chart labels itself
`app.kubernetes.io/version: 18.6.0` while the actual image stays PostgreSQL **17**
(`17.7` → `17.11`): **the chart's version label does not mean a database major upgrade.**
Two values the 2026.x line needs and the chart no longer supplies (in `locals.tf`, with
`pod_cidr` passed from `stacks/core/auth.tf`): `listen.http/https/metrics = 0.0.0.0:…`
(2026.5 changed the default listen IP `0.0.0.0` → `[::]`, and 2026.8.2's chart stopped
setting all three) and `listen.trusted_proxy_cidrs = "<pod_cidr>,127.0.0.1/32"` (2026.8 only
honours `X-Forwarded-*` from trusted proxies; NGF is the only hop). **`trusted_proxy_cidrs`
must be a comma-joined string** — the chart flattens nested values into env vars and would
otherwise render the YAML list as the literal `[10.244.0.0/16]`.
The provider is coupled to the app: `stacks/mantle` now pins authentik `2026.8.0`, and
`init -upgrade` surfaced **4 in-place `authentik_provider_oauth2` updates that would not
converge** — dropping `redirect_uri_type` from every `allowed_redirect_uris` entry, re-added
on read. Declaring `redirect_uri_type = "authorization"` in
`modules/auth/authentik/oidc_provider/auth.tf` converges it (our config had never set it, so
this is API-driven state noise, not drift). All four providers still validate their
registered redirect URIs: 302 into the login flow with the real `redirect_uri`, 400 with a
bogus one.

**Also learned / deliberately left alone.** A failed `tofu apply` of a helm release **does**
leave the attempted chart version in TF state (the failed 2026.8.2 attempt replanned as
`2026.8.2 -> 2025.12.4`), so a mid-flight failure is recovered by pinning *forward*, not by
re-importing. `ak_groups` in the groups property mapping is deprecated as of 2026.2
(`request.user.groups` replaces it) but still functions in 2026.8 — deliberately **not**
bundled in, since it is the claim every app's RBAC reads. Still open from the old backlog:
**NGF `2.7.1`** and **seaweedfs `4.47.0` + CSI `0.2.38`**.

## The whisker tier fix — hand-applied, then imported (2026-09-16)

The long-form record; the one-paragraph version is under "What works". Sequence:

1. **Symptom** — `https://whisker.vn.linuxguru.net` → `code=000`, gateway healthy. Root
   cause is the tier change above: everything in `calico-system` lost both directions, so
   the outpost could not resolve DNS (`i/o timeout` on `:53`) or reach `authentik-server`,
   never fetched its config, and the UI was dead in-cluster too.
2. **Design** — `modules/network/whisker/tier.tf` (3 CRs, one per hop, each pod-scoped and
   tighter than the k8s policies they shadow, incl. the previously-unpoliced gateway hop).
   `gateway_name = "private"` is what the gateway-hop selector pins. The k8s policies are
   kept as the portable statement of intent, deliberately inert.
3. **Blocker** — the mantle apply that would have created them aborted on the unrelated
   authentik lookup (fixed the same day, below), so the CRs were rendered by `tofu` and
   `kubectl apply`ed from `/tmp/whisker-tier/{1-outpost-egress,2-outpost-ingress,3-whisker-ingress}.yaml`.
   `--dry-run=server` accepted all three first, and the operator's canonical selector key is
   `namespaceSelector: projectcalico.org/name == '<ns>'`. Once the lookup was fixed they were
   `tofu import`ed, and that apply's only live delta on them was the provider's bookkeeping
   (`managedFields` + the `last-applied-configuration` annotation) — i.e. the hand-applied YAML
   and the module's render agree. **Trap:** a naive `sed 's/^tier_//; s/_/-/g'` on the resource
   name loses the `whisker-` prefix and yields `outpost-egress-tier`; the live names are
   `whisker-outpost-egress-tier` / `whisker-outpost-ingress-tier` / `whisker-ingress-tier`.
4. **Second, misleading failure** — after the CRs landed, tests went from *hang* to **502**.
   That is progress, not a bug: policy now passes and the socket is refused. The outpost had
   backed off exponentially on its failed config fetches and held no `:9000` listener;
   `kubectl rollout restart deploy/whisker-auth` brought it up
   (`Successfully connected websocket`, `Starting HTTP server 0.0.0.0:9000`,
   `Loaded application host whisker.vn.linuxguru.net`). **Remember this one** — a
   policy-restore that does not fix the symptom may just be waiting on a backoff.
5. **Verification** (all post-restart): `GET https://whisker.<domain>/` → `302` →
   `/outpost.goauthentik.io/start?rd=…`; following redirects lands on
   `auth.<domain>/if/flow/default-authentication-flow/?client_id=…&scope=…ak_proxy` with
   **200** (`ak-flow-executor` / `authentik` markers in the body). Flow audit over the
   window: **no `Deny` touching `calico-system`** except the pre-apply one, which is
   attributed to `EndOfTier/calico-system` — the mechanism, confirmed in the data.
   `whisker-backend` returned no rows for the outpost → `whisker:8081` hop simply because
   only a *logged-in* session generates that traffic; the ordering rule (explicit `order`
   beats the operator's unset-order deny-all) is what makes that hop provably allowed.
6. **Residue** — none in state: the 3 CRs were `tofu import`ed 2026-09-16 (address
   `module.whisker.kubectl_manifest.<tier_*>`, import id
   `apiVersion//Kind//name//namespace`) and are applied by mantle. One browser sign-in is the
   last unconfirmed step (the logged-in UI through the proxy).

## The firewall layer was deleted (2026-09-16)

Removed rather than repaired: the whole policy system came out so every workload can talk to
every other one, and it gets rebuilt from scratch if it is ever wanted again. What went:

- `modules/network/firewalls/` — `policy` (the single renderer), `basic_egress`,
  `limited_ingress`, plus the older `allow_api` / `basic_internet`, READMEs included.
- Every per-app `security.tf`: `argo/core`, `auth/authentik/core`, `cert_manager`,
  `harbor/core`, `media`, `storage/longhorn-security.tf`, `storage/seaweedfs/security.tf`,
  `vaultwarden`.
- The wiring: the `api_peer_ips` / `lan_cidrs` / `cluster_cidrs` / `enable_egress_firewall`
  variables (`system_namespace` survives only in `network/whisker`, which needs it),
  `data.kubernetes_endpoints_v1.kubernetes` +
  `local.api_peer_ips` in `stacks/core/core.tf`, `network/gateway`'s
  `cert_generator_job_name` output, the `firewalls` + `policy` module calls in
  `storage/seaweedfs_admin` and `network/whisker`, and `proxy_outpost`'s `core_egress`.
- The docs that described it (root/network/gateway/media/storage/blender/vaultwarden/
  seaweedfs_admin/proxy_outpost/route53_record READMEs, `storage/disaster_recovery.md`,
  `.clinerules/resources.md`). `modules/cert_manager/README.md` kept the *why* an ingress
  rule there breaks issuance cluster-wide, minus the module.

**What to expect:** the dead policies are still in state and on the cluster, so the next
apply of each stack destroys them. `tofu validate` is clean on all three stacks (checked
2026-09-16) and no other module referenced a deleted output or variable (grep-verified), so
the diff is policy-object destruction only. The three `stacks/*/.terraform/modules/modules.json`
manifests also still listed 34 dead `firewall*` keys (the module dirs themselves were already
gone) — pruned by hand, and `init` + `validate` stayed clean afterwards. Hand-made Calico
`Staged*NetworkPolicy` CRs are not typed resources — check for strays with
`kubectl get stagedkubernetesnetworkpolicies -A` (the staging experiment ran on `argo`).

**Also cleaned outside the repo:** the tfenv carried one dead key and two stale comments from
this system — `metal.local_lan` (only the firewall modules read it, and its comment named
media's ingress firewall) and the `network = {...}` comment calling `pod_cidr`/`service_cidr`
"the single source of truth for the firewall modules". All three are gone from
`~/.tfenvs/k8s.tfenv` (backup `k8s.tfenv.bak.20260916-201448` taken first); the CIDRs
themselves are still read by the modules that need them. The hand-made router NAT rules
(WAN 443 → public gateway, WAN 21010 → torrent) are unaffected and remain the one thing DNS
cannot cover — `modules/network/gateways.tf`.

Invariants that made the old layer expensive are kept as a post-mortem in
`.clinedocs/calico-netpols.md`; flow-query recipes in `.clinedocs/flow-logs.md`.

## What's left / open

- **Monitoring's egress closure is dropped with the rest of the layer.** Kept only as the
  shape any rebuild would need: a `basic_egress`-style policy with `allow_cidrs = [var.pod_cidr,
  <node IPs>/32]` (Prometheus scrapes pod IPs and node-exporter/kubelet on the node IPs, which
  are inside the cluster CIDR) **plus `allow_k8s_api = true`** — Prometheus' own
  `kubernetes_sd_configs` list pods/services/endpoints/nodes, so a DNS+CIDR-only policy breaks
  target discovery. No data source publishes node IPs yet (candidates: the node-exporter
  Service's endpoints, or a local from `var.deployment.metal`). Grafana's 10-minute
  update/plugin checks are already off in `modules/monitoring/prometheus/locals.tf`.
- **Whisker's tier CRs and mantle's authentik blocker are both closed out (2026-09-16).** The
  3 CRs are imported into state and applied — the hand-applied render and the module's render
  agree, so nothing about the live policy changed; the `data.authentik_certificate_key_pair
  { name = "tls" }` lookup is gone, replaced by Terraform-owned per-provider signing keys
  (root cause, fix, verification and the *why-not-stopgap* reasoning: `activeContext.md`).
  Only the logged-in whisker UI (one browser sign-in) remains unconfirmed.
- **Nothing is in flight for network policy.** The namespace-ingress rollout was cancelled with
  the layer (2026-09-16 — see the deletion section above); method, invariants and lessons are in
  `activeContext.md` and `.clinedocs/calico-netpols.md`.
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
  **Whisker UI**: the entry path is live as of 2026-09-16 (302 → outpost → authentik flow
  200, see the tier-fix section); what is still unconfirmed is the *logged-in* UI, i.e. the
  outpost → `whisker:8081` hop and the UI's live flow stream through the proxy — one browser
  sign-in settles it.
- **`signups_allowed` must go back to `false`** after any first-account bootstrap
  (`stacks/mantle/vaultwarden.tf`; `signups_allowed = true` → register → back to
  `false`); see the vaultwarden README.
- **vaultwarden has nothing to scrape** — 1.37.3 dropped the metrics build (no
  `/metrics`, no `PROMETHEUS_ENABLED`, only `GET /alive`), so the module ships no
  ServiceMonitor. If upstream restores it, add `monitoring.tf` (there is no netpol layer left to
  add `monitoring` to).
- **Rebuild gaps that are hand work, not state:** authentik group membership is
  UI-managed → members must be re-added by hand; per-app one-time config (arr apps
  `AuthenticationMethod = External`; qBittorrent pod-CIDR WebUI whitelist + hard pod
  kill; vaultwarden first-account bootstrap); `library` exists by default in Harbor, so a
  rebuild is fine — but the hand-made `robot$jblack` permission on it is not recreated by
  anything.
- **Chart upgrade backlog** — the *pin* debt is paid (every `helm_release` is version-pinned
  as of 2026-09-16; the awk audit in the pinning entries above is the check). What is left is
  the *version* gap. Done 2026-09-16: cert-manager, argo-events, external-dns,
  kube-prometheus-stack, argo-cd. **Own project + maintenance window:** argo-workflows
  `0.46.4` → `2.0.6` (two chart majors *and* an app major; the release binds
  `${name}-argo-workflows-server` / `-admin`, so check every consumer) and authentik
  `2025.10.3` → `2026.8.2` (the IdP for every OIDC app plus 4 outposts, and mantle's TF
  provider is pinned `2025.10.1` — probe a 4-302 OIDC login after, and the proxy image moves
  to `ghcr.io/goauthentik/proxy:2026.8.2`). **Then, one at a time after reading the
  changelog:** NGF `2.6.7` → `2.7.1` (all three releases together; re-read the cert-generator
  hook note above — the Gateway API CRDs come from `core`'s bootstrap), seaweedfs `4.47.0`
  then its CSI `0.2.38`, tigera-operator `v3.31.2` → `v3.32.2` (data plane — last), and the
  media arr patches (bazarr, prowlarr, radarr, sonarr). Already at upstream-latest, no
  action: metallb, longhorn, harbor, metrics-server, snapshot-controller, plex,
  wireguard-operator, smartctl. Not upgradable here at all: the `apps` charts (ollama,
  corsless, llm-embedder) are `0.0.*` wildcards synced by Argo from the external repo.
- **Optional, if policies ever return**: a `posture` wrapper so a namespace states
  egress+ingress in one call instead of 2-4 module calls.
- **Accepted risks**: `goldmane:7443` readable by any pod (unfixable from TF); media
  NodePort soft spot (`nodeIP:nodePort` bypass — moot while nothing is policed); `ollama`
  has no auth in front of it.


## Evolution of decisions worth knowing

- `allow_ingress` → renamed `limited_ingress` (2026-09) because the old name read like a
  blanket allow when it is a lockdown with a guest list. Docs/paths only — no resources
  moved. The older `namespace_only` is gone too, replaced by `limited_ingress` with a
  one-namespace guest list, typed instead of `kubectl_manifest`. The whole family
  (`namespace_only` → `allow_ingress` → `limited_ingress`, plus `allow_api` →
  `firewall_api` → folded into `basic_egress`) was deleted outright 2026-09-16, four days
  after `media` was the first namespace locked down — see the deletion section above.
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
  pre-compression text of any file is at `git show HEAD:<path>` (they were uncommitted
  until the 2026-09-16 sweep).
- **`*.tf` comments were trimmed 2026-09-16** (same day as the docs pass above): one rule
  — keep what explains non-obvious behaviour or an HCL/provider constraint, drop
  narrative history, verification dates, README pointers, design rationale and code
  restatements. Surviving examples worth not re-deleting: the JMESPath `&&`/`||`
  precedence parens (Grafana), the RWO-volume RollingUpdate deadlock, the control-plane
  scraper loopback gotcha, the Helm CRD upgrade hole, argo-cd's
  `networkPolicy.create = false` rationale, authentik group-name matching for argo-cd RBAC,
  argo-workflows `redirect_uri` scheme pin, plex's `externalTrafficPolicy=Local` VIP note,
  blender's mDNS/hostNetwork selector-collision trap, the MetalLB-VIP/router-rule coupling,
  the Longhorn-labelled-PVC group-set replacement, and the post-DNAT semantics that now live
  only in `whisker/tier.tf` + `.clinedocs/calico-netpols.md` (the `firewalls/allow_api`
  comment went with the module).
  **One casualty, caught by `validate`:** the trim silently took
  `variable "private_gateway_ip"` out of `modules/vaultwarden/variables.tf` along with
  its comment (mantle red with "An argument named private_gateway_ip is not expected
  here" until restored). **Lesson:** after any "comments only" pass, diff the *removed
  non-comment* lines (`git diff -U0 -- '*.tf' | grep '^-' | grep -v '^-[[:space:]]*#'`)
  and eyeball each one, then `tofu fmt -recursive -check` + `tofu validate` per stack.
  Clean as of 2026-09-16; the only remaining removed code lines are a variable
  `description` reword and a blank line.
- **State lives in the Kubernetes backend** (`kube-system`, `secret_suffix =
  core|mantle|deployment`), so an interrupted command leaves no local lock file and a
  local `ls` for `*.tfstate.lock.info` proves nothing. **The lock is a `Lease` named
  `lock-tfstate-default-<stack>` in `kube-system`** (the `HOLDER` column is the lock ID) —
  *not* the `tfstate-default-<stack>-lock` Secret these notes used to name;
  `kubectl get secret -n kube-system | grep -i lock` returns **nothing**, which will talk
  you into force-unlocking a client that is very much alive. The Lease also *outlives* a
  clean exit with an empty `HOLDER`, so emptiness proves nothing either: run
  `ps aux | grep '[t]ofu'` and only `tofu -chdir=stacks/<stack> force-unlock -force <ID>`
  when it shows no live client (an interrupted `plan` holds the lock with
  `OperationTypePlan` and has written no state).
- **An interactive `tofu apply` parked at its approval prompt holds the lock with
  `OperationTypeApply` and has applied nothing.** Tell-tale: `ps` shows `S+` with flat CPU
  (1.31s across samples), `lsof` shows fds 0/1/2 on one tty and it is blocked in `read()`,
  and **no helm release revision has moved** (`kubectl get secret -A -l owner=helm` labels).
  Not a stale lock — don't clear it. Worse: that plan was computed *before* any edit made
  since, so a pin added while it sits at the prompt **is not in it**, and answering yes
  applies the old resolutions (here: the three chart bumps the pin was meant to prevent,
  after which the new pin plans as a tigera-operator *downgrade*).
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

