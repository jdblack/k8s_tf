# Active Context

*Consolidated 2026-09-16; **the firewall layer was deleted that day and rebuilt narrower on
2026-09-17**, when this memory bank was also restored (see the last section).
State and in-flight work; the open list is `progress.md`.*

## Current state
- **Code comments were swept to the new rule (2026-09-17), committed as `a799916`** — 55 files of
  code and docs: **53 `.tf` (`+320/−685`)** plus `.clinerules/behavior.md` (the rule itself) and
  `network/firewalls/README.md`. The record you are reading followed as itself, and two stale
  cert-manager version lines as `ce24ded`. All 240 `.tf` files: comment lines **982 → 616**. The rule
  is one line max; the only blocks over 1 line are **file headers, capped at 4**, and they hold
  cross-cutting traps only (plan-time landmines, the tier mechanism) — app detail stays in the module
  README. Three places have **no README at any level** — `harbor/core`, `auth/authentik/core`,
  `argo/mantle/argo-workflows` — and there the comments are the only copy, so they were pruned most
  conservatively. Cut everywhere: module README
  duplication, verification narrative, README pointers, decorative `--- x ---` banners, code
  restatement. Two defects found and fixed: a **severed comment fragment** at the tail of
  `storage/egress.tf` (a block whose head had already been trimmed) and two **bare `#` separator
  lines** (`media/egress.tf`, `stacks/core/vpn.tf`) that fake-merged two unrelated comments into one
  block.
  **Checks to repeat after any comments-only pass:** `git diff -w -U0 -- '*.tf' | grep '^-' | grep -v
  '^-[[:space:]]*#'` must print nothing but `--- a/...` headers (the 2026-09-16 pass silently deleted a
  `variable` block along with its comment), `grep -rn '^[[:space:]]*#[[:space:]]*$' --include='*.tf'`
  must be empty, `tofu fmt -recursive -check modules stacks` exits 0, `tofu validate` passes in all
  three stacks.
  A block-size counter must reset at `FNR==1`, or it merges a file's last comment block with the next
  file's first and over-reports.
- **`kube-storage` is the fourth namespace closed, and the second shape (2026-09-17).** `media` carries
  a namespace *profile* (self + DNS + the public internet); `kube-storage` carries the **closed floor**
  used namespace-wide — `podSelector: {}`, own namespace + DNS and nothing else, 28 pods — because
  that is all its measured traffic is. Five policies: the floor + the API server for
  `seaweedfs-csi-controller`, `seaweedfs-csi-node` (whose `driver-registrar` is the namespace's only
  holder of CSI *write* verbs) and `snapshot-controller`, plus the co-located outpost's one
  `kube-auth` peer (`modules/storage/egress.tf`, `modules/storage/seaweedfs_admin/egress.tf`).
  Verified on the live cluster: 28/28 pods ready, a fresh `seaweedfs-csi` PVC bound and round-tripped a
  file, a `longhorn-snapshot` VolumeSnapshot reached `ReadyToUse`, a restarted CSI node pod
  re-registered (`PluginRegistered:true`, visible in Whisker as `→ PRIVATE NETWORK:6443 Allow`), SSO on
  `admin.seaweedfs.<domain>` still 302s, `/media` (8.5T RWX) still lists, and the 30 minutes of flows
  after the change held **zero Deny**. Ordering: mantle's outpost peer landed *before* core's floor, so
  the floor was a no-op for that pod — the reverse would have been an SSO outage between two applies.
  **Transferable lesson (also in `.clinedocs/flow-logs.md`):** where a policy depends on whether a pod
  talks to the API, flow logs cannot answer it — watches are never emitted. The tiebreak is the pod's
  own RBAC **plus** a live socket check (`/proc/net/tcp`, port `0x192B` = 6443, readable from any
  container in the pod because `/proc/net/tcp` is namespace-scoped). Doing both is what separated "the
  CSI registrar writes CRDs, so it needs the API" from "the chart ships a `pods` CRUD role nothing
  uses".

- **`kube-certificates` is the fifth namespace closed, and the second in a row to need no probe of the
  pods themselves (2026-09-17).** Two policies (`modules/cert_manager/egress.tf`): a namespace-wide base
  = DNS + self + **the API server**, and `allow_internet` for `component=controller` alone. The API grant
  is deliberately on the *namespace* rather than on three pod-scoped calls, because every pod that chart
  renders is an API client — controller, cainjector, webhook and the `startupapicheck` hook Job, which
  carries only `job-name` labels: the NGF cert-generator shape that a closed floor broke once already.
  The controller's internet grant is the load-bearing, invisible half: ACME registration, the Route53 API
  for DNS-01, and the public recursors `locals.tf` pins — the 30-day flow window holds **zero** records
  for this namespace, so it came from RBAC (nine `cert-manager-*` ClusterRoleBindings), the controller's
  own `"Caches populated"` reflector lines, and every ACME `order` reading `valid`. Probes on both
  selectors: API **403**, `acme-v02…` **200**, `1.1.1.1` **301**, `nslookup @8.8.8.8` answers; LAN `:80`,
  a `media` pod on `:8989` and (for the base-selected probe) all public egress time out. Post-apply plan:
  `No changes`. **Ingress stays absent on purpose here** — the apiserver reaches the webhook from the
  nodes, so any inbound restriction breaks issuance cluster-wide — and the ingress guest list is empty
  anyway: no ServiceMonitor exists for the chart, so nothing scrapes it.

- **`argo` is the sixth namespace closed, and the first where the namespace-wide selector is *forced*
  (2026-09-17).** Four policies (`modules/argo/core/egress.tf`): a **namespace profile** — DNS + self +
  the API server + the public internet — plus three `egress_peer` calls for the private gateway's data
  plane on 443. The reason the floor has to be namespace-wide is argo-wf: its **workflow pods** are pods
  nobody declares, they run arbitrary containers, and their executor patches its own `Workflow` CR — a
  per-pod audit cannot see them. What the change *removes* is the point: every argo pod could previously
  reach the LAN, the gateway VIP and every other namespace's pods. The three peers are for the only three
  dialers, and the guest list was read, not guessed — the measured flows (github over public :22, the
  `otwld.github.io` helm repo over :443, and `harbor.<domain>` OCI through the gateway on :443) line up
  one-for-one with the four live Applications' `repoURL`s, and the peer is the **gateway pod, not an
  authentik pod** (the harbor lesson). Acceptance test worth reusing: force-refresh the Applications
  (`argocd.argoproj.io/refresh=normal`) *after* the apply — all four came back `Synced`/`Healthy` with no
  conditions, so repo-server really re-fetched from all three upstreams through the new policies; and
  `argo-cd.<domain>/auth/login` still **303**s to the authentik authorize URL with `client_id=argo-cd`.
  Probes: OIDC discovery **200**, `harbor.<domain>/v2/` **401**, `github.com` **200**, API **403**, and
  the unlabelled base pod reaches the internet + API but **no** gateway peer. Zero Deny from any real
  argo pod in the window after; post-apply plan `No changes`. **Not done on purpose:** no ingress rules —
  inbound is untouched and nothing needs fencing, since the only guests are the gateway (already inside
  the cluster) and Prometheus, which does not scrape argo at all.

- **The inbound direction has its first policy, and it closed a namespace without a CIDR peer
  (2026-09-17).** `kube-storage-baseline-ingress` (`modules/storage/ingress.tf`): namespace-wide, four
  rules — self, the node floor, the private gateway's data plane on the three backend ports its own
  HTTPRoutes name (s3 `:8333`, master `:9333`, authentik outpost `:9000`), and Prometheus on `:9327`.
  Verified live: `s3.vn` 403 AccessDenied, `master.seaweedfs.vn` 200, `admin.seaweedfs.vn` 302, 0 Deny
  after, and Whisker names the guest as `kube-network/private-private-*` on `:9333` and `:9000`.
  Two lessons worth keeping: **the S3 consumers outside this repo are covered without being enumerated**
  — every Service in the namespace is ClusterIP, so the gateway pod is the only door a LAN or VPN client
  can arrive through, and a pod selector can name that door exactly; and **the scrape guest is invisible
  in Whisker** (Prometheus holds the connection open, so there is no flow record — it was found in
  `up{namespace="kube-storage"}`, 13/13). Reading flows alone would have denied the scrape on the next
  reconnect, minutes later, and it would have looked like a dead exporter rather than like policy.
  **Re-checked a day later, still green:** 13/13 `up`, zero `Deny` into the namespace, and a 32 MiB
  write into the 2Pi RWX share (`movies-archive`, the `media` apps' claim) read back with an **identical
  sha256 from four pods on four different nodes** — so the whole CSI path (pod → mount pod → filer →
  volume server) is untouched.

- **Egress policy is back, curtain-first then holes, through two modules:
  `network/firewalls/egress` + `network/firewalls/egress_peer`** (`1912b7c`, the second added
  2026-09-17). One call = one `policyTypes: ["Egress"]` NetworkPolicy; DNS and own-namespace
  always, everything else by explicit switch (`allow_k8s_api`, `allow_cluster`,
  `allow_internet`, `to_namespaces`, `to_cidrs`), and `egress_peer` for the one shape the first
  cannot say — namespace + pod selector + port. Live today: **20 policies** — `blender` (1:
  DNS + self only), `vaultwarden` (1: the same two rules, applied 2026-09-17), `media` (4: one
  namespace profile — `media-baseline-egress`, `podSelector: {}` = own namespace + DNS + the public
  internet — plus `ngf-egress` and `ngf-cert-generator-egress` for the API server and
  `authentik-outpost-egress` for one `kube-auth` peer; see the bullet below) and
  `devops-harbor` (3, applied 2026-09-17: DNS + self for all seven chart pods, `+ allow_internet`
  for trivy, `+ the private gateway's data plane on 443` for harbor-core's OIDC) and `argo` (4,
  applied 2026-09-16: a namespace *profile* — DNS + self + the API server + the internet,
  namespace-wide because argo-wf's workflow pods are pods nobody declares — plus the private gateway's
  peer on 443 for the three pods that speak to it) and `kube-certificates` (2, applied 2026-09-16: the
  namespace-wide base — DNS + self + the API server, since every pod that chart renders including its
  `startupapicheck` hook Job is an API client — plus `+ allow_internet` for the controller alone) and
  `kube-storage`
  (5, applied 2026-09-17: the namespace-wide **closed floor** + the API server for the CSI controller,
  the CSI node DaemonSet and `snapshot-controller`, + the outpost's `kube-auth` peer — the bullet at
  the top of this file). `harbor/mantle`
  gets none — no pods there, and that is now the documented rule for config-only modules
  (`network/firewalls/README.md`). The per-pod tables and the evidence per peer are in
  `modules/media/README.md`, `modules/vaultwarden/README.md` and a one-line note on each call;
  wiring in `modules/network/firewalls/README.md`. The two directions are separate *call sites*, not
  separate philosophies: each namespace gets the curtain its threat direction calls for (egress for
  `media`, ingress for `kube-storage`), and a namespace that is dangerous neither way gets neither.
  The ingress half landed a day later — one namespace deep, below.
- **The ingress half is ONE module, and two namespaces use it (2026-09-17).**
  `network/firewalls/ingress` renders a whole `policyTypes: ["Ingress"]` policy from one call: the same
  contract as `egress` (callers state intent, `kubernetes.io/metadata.name` for namespace guests) plus
  `from_peers` — `{namespace, pod_selector, ports}`, one guest per rule, each carrying its own ports —
  which is the shape `egress` splits into a second module. `kube-storage` is its first call site (the
  bullet at the top of this file); `longhorn-system` took a pod-scoped one the same day, and the rest
  of the rollout is in § *The policy layer*. Divergences from egress, all
  direction-driven: the **node floor** (`allow_nodes`, on by default — kubelet probes and the
  apiserver's calls into a pod originate on a node's host network, so only an `ipBlock` per node
  `InternalIP` read live from `data.kubernetes_nodes`, v4-only, can admit them; drop it and probes die),
  no service-CIDR peer (DNAT rewrites the destination, so a guest's port is the pod's port),
  `allow_internet` = `0.0.0.0/0` minus RFC1918 + link-local, and an empty call renders `ingress = []` =
  deny-all rather than "empty means anywhere". **Verified by plan against the live cluster** (scratch
  root in `/tmp/ingressplan`, `kubernetes` 3.0.1): render order self → from_namespaces → nodes → cluster
  → internet → from_cidrs → from_peers, duplicates collapse, peer guests keep their own ports.
  **The `ingress_peer` module was built first and deleted the same day** — see below.
- **A duplicated renderer is a security bug waiting, measured (2026-09-17).** `ingress_peer` was written
  as the mirror of `egress_peer` before any caller existed, and within the hour the two `from` renderers
  had diverged: `ingress_peer`'s had no `ip_block` block, so its node floor rendered as six **empty
  `from {}` peers**, which in NetworkPolicy means *from anywhere* — an allow-all-inbound where a floor
  was intended. The plan against the live cluster is what caught it. Folded instead: `from_peers` lives
  in `ingress`, where there is exactly one place for a rule's peer blocks to go wrong. `egress_peer`
  stays (five live call sites; moving applied objects buys nothing), but the same fold is the shape to
  reach for if egress is revisited. **Rule for both: a rule's peer block must render, or the peer means
  everything.**
- **Per-pod closing is not namespace closing — and `media` now does it at the namespace (2026-09-16 →
  2026-09-17).** An unselected pod falls through to the Kubernetes default-allow namespace profile
  (`kns.media`: `egress: [{action: Allow}]`): LAN, gateway VIP, API server, internet. The hand-made
  `utility` pod in `media` (one label, `app: utility`, no owner, selected by nothing) got **200** from
  `vaultwarden.linuxguru.net` (`192.168.0.100`, the private gateway VIP) while sonarr and the outpost
  timed out on the same URL in the same minute. First fix was the **closed floor** — one `egress` call
  with no `pod_selector` (`podSelector: {}`, every pod present and future) and no grants, so its whole
  grant was DNS + self. It was a no-op for the nine pods already selected (netpols union; every call
  keeps self + DNS), `plan` said 1 to add / 0 to change, and probes reconfirmed it. **Then the shape
  changed on the user's call:** the same call now carries `allow_internet = true`, making it the
  **namespace profile** — own namespace + DNS + the public internet for everything in `media`, with
  per-pod calls only for exceptions (API server for the gateway and its cert-generator hook pod, one
  `kube-auth` peer for the outpost). Seven per-pod calls that had become byte-identical no-ops were
  deleted; `media` went 10 → 4 policies and the repo 15 → 9. The trade, recorded: a namespace-wide
  grant can't be subtracted from, so **no pod in a profiled namespace can be internet-less**, and
  the six apps no longer carry a per-app statement of their own reach.
  A namespace-wide call *inverts* the failure mode of any later call that drops the self or DNS rule
  — it becomes wider, silently. **It also closed a fall-through that a helm hook was relying on:** NGF's
  cert-generator hook pod carries no chart labels (only `job-name=ngf-nginx-gateway-fabric-cert-generator`),
  so `ngf-egress` never covered it and the floor left it DNS + self — measured `rc=28` against the API
  where the `app.kubernetes.io/name=nginx-gateway-fabric` pod gets `403`. Fixed with
  `ngf-cert-generator-egress`, the name coming from `modules/network/gateway`'s new
  `cert_generator_job_name` output; probe now reads `403`. Lesson for every other namespace: enumerate
  its *transient* pods (hook Jobs, CronJobs, one-offs) before touching its floor.
  **Kept on purpose and unrelated:** `modules/network/whisker/tier.tf` — 3 Calico CRs at
  `spec.tier: calico-system` that are not a restriction but the thing that makes whisker work at
  all. Invariants: `.clinedocs/calico-netpols.md`; flow queries: `.clinedocs/flow-logs.md`.
- **A LoadBalancer VIP is not a policy peer (measured 2026-09-17).** Egress is evaluated
  POST-DNAT, so `to_cidrs = ["192.168.0.100/32"]` on harbor-core permitted nothing: the gateway
  VIP had already been DNAT'd to the NGF data plane pod (`kube-network`,
  `private-private-6f99f96d5f-*:443` — named by the deny record). The working peer is
  `egress_peer` with `gateway.networking.k8s.io/gateway-name`. This corrects the "reach the
  registry by its LAN CIDR" advice that used to sit in `firewalls/egress/README.md`. It also
  generalizes: **every** OIDC consumer in this repo (harbor, grafana, argo — all `auth.<domain>`,
  all `.100:443`) needs the same peer, and the three outposts need `kube-auth` on `:9000`.
- **The 2026-09-17 layer is committed, and the stack is clean.** Five commits: `514222b` (the module
  pair plus five namespaces, 28 files), `e64a54a` (the two `.clinedocs` notes on the API/RBAC
  question), `fc5fd43` (memory-bank tracked again), `be82dd2` (the last "no policy here" claims), and
  `c889d23` (six spent `moved` blocks). Both stacks report **no changes** against the live cluster,
  and the applies that produced them were no-ops. `memory-bank/` was untracked from 2026-09-16 until
  `fc5fd43` — **it is tracked now**, so update it in commits rather than leaving it aside.
  Next namespace: `kube-certificates`, then `monitoring`, `argo`, `kube-network`, `kube-auth`.
- Branch `main`, **ahead of `origin/main`, not pushed** — the 2026-09-16 sweep plus the 2026-09-17
  firewall rebuild and its cleanups (`514222b` … `c889d23`).
- **VIP policy: everything floats, names are the interface.** `gateway_ips` is deleted
  from `modules/network` (with tfvars `network_ingress` and the `stacks/core/core.tf`
  argument, its only consumers); `qbittorrent_torrent_lb_ip` is unset (variable kept as
  the re-pin escape hatch); vaultwarden's Route53 A record reads the private gateway's
  live data-plane Service (`kubernetes_service_v1` data source in
  `stacks/mantle/vaultwarden.tf`). MetalLB keeps an assigned IP when
  `spec.loadBalancerIP` is cleared, but a **recreated** Service gets a different pool IP
  — so only the two router NAT rules (WAN 443 → public gateway, WAN 21010 → torrent) ever
  need re-pointing, and only on a recreate. **Applied 2026-09-16** (core 0/17/2; post-apply
  plan `No changes`; both gateways kept `.101`/`.100` with `loadBalancerIP` now cleared,
  data-plane pods not rolled). Unpinning evidence + current assignments: `progress.md`.
- **All charts are version-pinned (2026-09-16).** Nine releases were unversioned; all now
  carry a `version` equal to what is deployed — `modules/network/{calico,external_dns}.tf`
  (`helm_calico_version = v3.32.2`, `helm_external_dns_version = 1.22.0`), smartctl
  (`0.17.1`), and harbor `1.19.2` / metrics-server `3.14.0` / snapshot-controller `5.2.0` /
  argo-cd `10.9.1` / argo-events `2.4.27` / plex `1.9.0`. The pins came from the *unpinned*
  core plan, which was silently dragging tigera-operator `v3.32.2`, external-dns `1.22.0`
  and smartctl `0.17.1` along with the `timeout` bumps. The six late pins cost **no apply**
  (state already recorded those versions; core replans `No changes`). **Five of them have
  since been upgraded, one apply each (2026-09-16):** cert-manager `v1.21.2`, argo-events
  `2.4.27`, external-dns `1.22.0`, kube-prometheus-stack `91.4.1`, argo-cd `10.9.1`; both
  stacks re-plan `No changes`. Two things learned the hard way and worth not rediscovering:
  **external-dns 1.22.0 made `policy` required** (bump-only = schema-validation failure, so
  `charts.tf` now sets `policy = "upsert-only"`), and **argo-cd `10.0.0` ships
  `global.networkPolicy.create: true`** (six new ingress netpols in a namespace that has
  none — set `false` in `locals.tf`, which makes 10.9.1 render the same 54 objects as
  `9.2.4`). **The rest of that backlog has since been cleared too (2026-09-16, still one
  apply each):** smartctl `0.17.1`, the four arr patches (bazarr `2.3.1`, sonarr `2.2.3`,
  prowlarr `3.8.4`, radarr `3.6.4` — image-tag-only moves), tigera-operator `v3.32.2`,
  argo-workflows `2.0.6` (app `v4.1.3`) and authentik `2026.8.2` (+ its provider
  `2026.8.0`). Three traps in that batch are worth knowing before the *next* chart bump:
  **calico 3.32 deleted the chart's whole `crds/`** (CRDs now come from the separate
  `crd.projectcalico.org.v1` chart and must be applied *before* the operator, which needs
  `--force-conflicts` because the helm provider owns `.spec.versions`); **argo-workflows
  1.x/2.x moved its CRDs out of the manifest into a pre-upgrade hook Job**, so helm would
  have deleted all 8 — they are now `helm.sh/resource-policy: keep`; and **authentik refuses
  major version skips**, which is the crash this repo pinned it for — 2025.10.3 → 2026.8.2
  had to go `2025.12.4` → `2026.2.3` → `2026.5.6` → `2026.8.2`, four applies. **NGF `2.7.1`
  is done too** (see the NGF entry below). Still open from it: **seaweedfs `4.47.0` + CSI
  `0.2.38`**.
- **Whisker was killed by that same tier change and is fixed (2026-09-16).** tigera-operator
  `v3.32.2` moved its own rules into tier `calico-system`
  (`order: 100`, `defaultAction: Deny`), which outranks the `default` tier every k8s
  NetworkPolicy here compiles into, so the UI returned `code=000` with the gateway healthy.
  The fix is `modules/network/whisker/tier.tf` — three pod-scoped Calico `NetworkPolicy` CRs
  at `spec.tier: calico-system`, `order: 10`. They were `kubectl apply`ed first (mantle's apply
  was blocked by the keypair below) and are now **in state** — imported, since a plan otherwise
  offers 3 creates that 409; kubectl-provider import id is
  `crd.projectcalico.org/v1//NetworkPolicy//<name>//<namespace>`. **Verified**: `302` → outpost →
  authentik flow page `200` (`ak-flow-executor` in the body); the outpost's DNS timeouts went to
  0; flow records name `whisker-outpost-ingress-tier` the deciding policy for gateway →
  outpost:9000. Two things to carry: an in-tier CR needs an explicit `order` to beat the
  operator's *unset-order* deny-alls (`.clinedocs/calico-netpols.md`), and **the outpost must be
  restarted once the tier lands** — exponential backoff had left it with no `:9000` listener, so
  the gateway served `502` (upstream RST, policy already passing) until `rollout restart`.
  Open: one browser sign-in for the logged-in UI hop.
- **The proxy outpost is one module now (2026-09-16).** `auth/authentik/{proxy_app,outpost}`
  merged into `auth/authentik/proxy_outpost`: one call per protected app (media, whisker,
  seaweedfs_admin) owns the authentik provider/application/group/outpost, the outpost's token,
  and the Deployment/Service/Secret + core egress carve-out. The token was the point — it used
  to be a `sensitive` output passed straight into the sibling module. `core_url`/`browser_url`
  are locals now (derived from `domain` + `core_namespace`; three callers passed the same two
  strings, including a hardcoded `authentik-server.<ns>...` literal) and `outpost_token` is no
  longer an output. **State moves with 4 `moved` blocks per caller — a whole-module
  `moved { from = module.outpost to = module.auth }` does NOT work** when the destination
  already holds resources: OpenTofu warns `could not move ... existing objects already at the
  intended addresses` and plans 9 destroys (only the nested `module.core_egress` maps). Those
  12 blocks are one-apply scaffolding, deleted after the move lands. **Applied in mantle**
  (`0 added / 0 changed / 0 destroyed` — moves touch state only; post-apply plan `No changes`;
  the outposts were *not* rolled, deployment ages still 09-09/09-12). **Core applied**
  `0 added / 0 changed / 2 destroyed` = the two dead `random_password`s below (`deploy_key`,
  `database` — nothing referenced them; `terraform_key` is the one the blueprint Secret uses);
  post-apply plan `No changes`.
- **Two authentik "simplifications" are recorded as rejected (2026-09-16).** (1) In the code
  that would tempt someone, `core/scopes.tf`: bootstrap env vars
  (`AUTHENTIK_BOOTSTRAP_TOKEN`/`_PASSWORD`) cannot replace our API-key blueprint —
  `core/setup/signals.py` gates the whole bootstrap on `not Setup.get(tenant)`, i.e. once per
  instance on a *fresh* install, so a running instance ignores them and rotating the key would
  mean flipping the Setup row in the DB. (2) `core/security.tf` (file deleted 2026-09-16) used
  to carry a factually wrong comment: the worker's API (`:6443`) rule was not about "the
  media-proxy outpost's service connection" — no outpost has one. `outposts`' connection
  discovery re-creates a local `KubernetesServiceConnection` every 8h if absent, and
  `outposts/models.py` gives **every** connection a 15-min `outpost_service_connection_monitor`
  (`crontab 3-59/15`) whose `KubernetesClient.fetch_state()` calls :6443. The durable part:
  that discovery makes an API allow-rule load-bearing and un-removable from Terraform, because
  the object is put back. The file was deleted 2026-09-16, so this note is the surviving record.
  `core/locals.tf`
  likewise documents why `/certs` stays: it feeds the server's :9443 listener *and* the cert
  discovery task (live: `auth.<domain>` + `ca`, `managed=goauthentik.io/crypto/discovered/...`);
  the OIDC providers no longer depend on it.
- **The authentik keypair that blocked every mantle plan is gone — replaced by a TF-owned
  signing key (2026-09-16).** `data.authentik_certificate_key_pair { name = "tls" }` stopped
  resolving, and it was never ours to resolve: authentik's cert-discovery task imports whatever
  it finds under `/certs` (where the chart mounts the TLS secret) and stamps it
  `managed: goauthentik.io/crypto/discovered/<name>`. Through 2025.10 that name came from the
  **file** (`tls.crt` → `tls`); **2026.8 added `tls.crt`/`tls.key` to the parent-DIRECTORY
  branch and renames the match in place**, so the `2026.8.2` chart bump alone renamed the object
  to `auth.vn.linuxguru.net`. Same pk, so the four OIDC providers kept working and only the name
  lookup broke — the reason this looked like a whisker/authentik mystery is that it blocked
  *every* mantle apply, whisker's included. `modules/auth/authentik/oidc_provider` now generates
  its own `tls_private_key` + `tls_self_signed_cert` + `authentik_certificate_key_pair` per
  caller (`<name>-signing`, RSA 4096, 10y, `digital_signature`) and references the resource
  directly: no name lookup, nothing for an upstream rename to break, and token signing no longer
  rotates with cert-manager's web cert (`kid` derives from the private key). Applied in mantle
  (`12 added / 8 changed / 0 destroyed`, post-apply plan `No changes`, four distinct kids on
  `/application/o/<slug>/jwks/`); the old discovered keypair stays, unused. **2026.8 renamed the
  API field `signing_kp` → `signing_key`** — a verification query on the old name reads `null`
  for every provider and looks like a missing reference. `hashicorp/tls` is
  pinned in `stacks/mantle/providers.tf`. Same apply carried the `goauthentik`
  `2025.10.1 → 2026.8.0` bump and its rewritten `.terraform.lock.hcl` — both **applied and
  committed, not reverted**.
  - **NGF `2.6.7` → `2.7.1` (2026-09-16, core + mantle).** Three releases in one apply.
    Two traps, both worth carrying forward: **helm applies `crds/` on install only** — this
    repo's Gateway API bootstrap existed, but NGF's own `gateway.nginx.org/*` CRDs did NOT,
    so `api_gateway_config.tf` now carries a second `terraform_data` (`ngf_crds`, tag pinned
    to the chart's `helm_version` via `triggers_replace`). That is safe on a live controller
    because 2.7.1's `filterControllersByCRDExistence` leaves new kinds
    (`ExternalLoadBalancer`, `PayloadProcessor`) inert until their CRDs exist. Verified after:
    all three NGF releases `2.7.1`, all data-plane pods `1/1 Running` 0 restarts, every
    `Gateway` `Programmed`, and the media gateway now reports the new
    `ClientSettingsPolicyAffected` condition (proof the 2.7.x controllers are live). A few
    benign `worker_processes is duplicate` / `Config apply failed, rolling back` lines appear
    in the controller log for ~4 seconds *during the data-plane roll* only, then
    `NGINX configuration was successfully updated`. Charts 2.7.1 requires k8s >= `1.32.0-0`
    (cluster is `1.35.8`) and upgrades the Gateway API to `v1.6.1`.
  Plan-reading traps, the audit one-liner, the empty-vs-empty `diff` trap and the stale
  `finalizers` key that was deleted from argo-cd's values: `progress.md`.
- **All 28 `moved` blocks are deleted** — every one was spent, and both stacks plan
  **No changes** without them. Rule and per-refactor detail: `progress.md` → Traps.
- **Mantle's hygiene batch is applied too (2026-09-16)** — exit 0, `0 added / 10 changed /
  0 destroyed`, post-apply plan `No changes`, **every chart version unmoved**. Real deltas:
  bazarr/radarr/sonarr gained `runAsGroup: 1000`, qbittorrent pinned
  (`…qbittorrent:5.2.3_v2.0.14-ls475`, `Recreate`), samba pinned, torrent VIP `.105`
  retained. It was *not* a clean run — see the next bullet.
- **The NGF cert-generator hook needed an API carve-out while netpols existed — and that
  constraint is back (2026-09-16; relevant again 2026-09-17).** The media gateway's helm upgrade
  once hung `Still modifying [id=ngf]` (`pending-upgrade`) because its `cert-generator` Job pods
  `Error`-looped on `dial tcp 10.96.0.1:443: i/o timeout`: a **Job's pods carry only the Job
  controller's labels** (`job-name`, …), never the chart's `app.kubernetes.io/name`, so a
  pod-scoped policy keyed on that label missed them. `media/ngf-egress` (selector
  `app.kubernetes.io/name = nginx-gateway-fabric`) selects the control plane, not the hook —
  nothing currently covers the hook's pods, which are unselected and therefore open. If that
  hook ever fails again under a tightened media namespace, this is the reason, and the fix is a
  second call keyed on `{ "job-name" = "ngf-nginx-gateway-fabric-cert-generator" }`.
- **Longhorn snapshots are one cluster-wide, TF-owned scheme and the restore path is
  verified end to end.** Jobs, enrolment table and the label trap: `progress.md` and
  `modules/storage/longhorn_jobs.tf`. Verified on throwaway objects: a revert is refused
  while attached *and* while detached; patching the VolumeAttachment ticket's
  `parameters.disableFrontend` works (no detach needed) and restored data really is
  pre-snapshot. **The manager API is in-cluster only:** `kubectl exec` into a
  `longhorn-manager` pod + `http://longhorn-backend:9500` (port-forward and the apiserver
  service-proxy both fail). **No `backupTarget`: recovery, not backup.**
- **The core-apply "inconsistent final plan" landmine is armed again (2026-09-16, and
  2026-09-17).** A pending change in any module under a caller's `depends_on` defers a
  `data` read inside that module, so the plan's `to` block count is a guess and the apply
  aborts. It last fired on the authentik policy module's Endpoints read; the fix then was to
  read in the stack root and pass the peer IPs down (that plumbing is gone). Today the same
  read lives in `firewalls/egress/data.tf` (the `kubernetes` Service **and** its Endpoints,
  whenever `allow_k8s_api = true`), so a `depends_on` over a pending change in any egress
  caller re-arms it: `.clinedocs/calico-netpols.md`; evidence: `progress.md`.
- **The CA migration is finished: all 19 hosts are on Let's Encrypt and nothing consumes
  `linuxguru-ca`** (dormant, not deleted; `var.ca_certfile`/`ca_keyfile` remain a standing
  **plan-time** dependency of `stacks/core`). Checklist:
  `modules/cert_manager/README.md`.

## The policy layer: thrown away 2026-09-16, rebuilt narrower 2026-09-17

The first attempt was a namespace-ingress rollout (staged policies → soak → enforce, `media` as
the model) that had been running for four days; it was deleted outright on 2026-09-16 and the
replacement is **a namespace-scoped curtain with holes poked in it — egress first, with the ingress
half returning on 2026-09-17** (`kube-storage`). Curtain first, outliers named after: measuring is
how you *find* the holes, not a gate to pass before building. Two lessons survived, and the second
one is a standing instruction:

- **Staging previews only where the staged policy is the deciding one** — a namespace with any
  permissive netpol just unions and previews nothing.
- **Put the `staged` flag in code from day one.** The first attempt proved the mechanism by hand
  and never implemented it, so every candidate namespace had to be fenced blind. Nothing stages
  policies today; add the flag to the module before any future "soak" step.
- **Guest lists come from real flow data** (`.clinedocs/flow-logs.md`), never from guessing — but
  the flows are read *after* the curtain lands, to name the holes: one call per pod profile, and a
  namespace nobody measured surfaces as breakage rather than as an excuse to stay open.

**Where the rollout stands.** Two questions per namespace, in this order: which way is it *dangerous*
(rules 1/2 → which direction the curtain drops), and is a pod in it worse than its namespace (rule 4 →
an exclusion). The old difficulty ranking is gone with the gate that produced it — a curtain is one
call, so the queue is set by threat direction, not by which slice is cheapest to test.

Curtains live: egress in `media` (the `podSelector: {}` profile — the first real curtain), `blender`
(pod-scoped on purpose — the same namespace holds a *hostNetwork* pod that still carries pod labels, so
a blanket selector would select it, and host-netns enforcement is untested), `vaultwarden`
(namespace-wide since 2026-09-17: verified as its only pod, so the blanket selector costs nothing and
covers whatever a chart upgrade leaves behind), `devops-harbor`, `kube-storage` (closed floor: self +
DNS, no internet), `argo`, `kube-certificates`; ingress in `kube-storage` (namespace-wide) and
`longhorn-system` (pod-scoped, the Prometheus scrape).

**Rule-driven, in order:**

1. **`pod_selector` gains `matchExpressions` / `NotIn`** in both builders — the one gating item. Two of
   the slices below want a pod excluded from a curtain, and neither can be written without it.
2. **`media` ingress (rule 4).** Today the only inbound path `media` wants is the gateway's data plane
   and the LAN into the app UIs; everything else reaching a media pod is unwanted. Plex (`:32400`) and
   qbittorrent (`:21010`, TCP+UDP) are the exception — they hold LoadBalancer Services that are *meant*
   to be reachable from outside, and ingress is evaluated post-DNAT on the destination pod, so
   curtaining `media` without excluding them kills streaming and every torrent peer. Rule 4's first real
   work order.
3. **`monitoring` ingress (rule 2).** The cheapest curtain in the cluster: the guest list is the
   gateway's data plane into grafana and nothing else, readable straight off the live listener.
   Nothing dials *into* monitoring. Its **egress stays open by choice** — see the declines.
4. **`kube-auth` ingress (rule 2).** It holds the credentials everything else trusts, so the curtain
   goes on the inbound side; guests are the three outposts on `:9000` plus the gateway, and they are
   read off the live listeners before the policy is written, never assumed.
5. **`longhorn-system` ingress curtain (rule 2)**, excluding `app=longhorn-manager` so
   `longhorn-manager-metrics-ingress` stays the authority instead of going redundant under the union —
   the rule-4 *mirror* case.
6. **`kube-network`'s gateway control plane (rule 1)** — the NGF controller pods and the core gateway's
   cert-generator Job, whose guest list is narrow and enumerable (apiserver + DNS). `media`'s
   `ngf-egress` / `ngf-cert-generator-egress` pair is the template. It goes in `kube-network`'s own
   file, never as a side effect of the gateway module (`progress.md`). The gateway **data plane** is a
   different animal — see the first decline below.

**Rule 2's leftovers — four namespaces holding half a profile.** Only `kube-storage` and
`longhorn-system` type `Ingress`; every other curtain is egress. Under rule 2 that is the direction
inverted for everything that holds credentials, and each is one call with a guest list already known
off a live listener (nothing to measure):

- **`vaultwarden`** — the vault itself; guest is the gateway's data plane, the same pod `kube-storage`
  names.
- **`devops-harbor`** — registry creds and robot accounts; guest is the gateway's data plane, which is
  also how argo's OCI pulls arrive (argo peers the *gateway*, never harbor: `argo/core/locals.tf`).
- **`argo`** — deploy credentials, it can write anywhere; guest is the gateway's data plane.
- **`kube-certificates`** — Route53 creds and ACME keys; the cheapest of the four, because the only
  inbound caller is the apiserver dialing the webhook from a node's host network — i.e. the
  `allow_nodes` floor, already on by default. Keep it on.

Prometheus is **not** a guest to copy by reflex: `serviceMonitorSelectorNilUsesHelmValues = false`
makes the selection cluster-wide, but the monitor population is `kube-storage`'s seaweedfs and
longhorn's, and `prometheus.io/scrape` appears nowhere in this repo — so check for a monitor aimed at
the namespace before naming one as a guest. This is the same class of work as items 3–5, not a new
phase.

**Recorded declines, so they are not relitigated:**

- **The gateway *data plane*'s egress.** It is rule 1 on paper — a compromised proxy is the biggest
  pivot into the cluster — but its legitimate reach *is* the pod CIDR: every backend anyone deploys,
  including namespaces created after the policy. A curtain there is the fall-through spelled out at
  length, and it costs a hole per new app; enumerating it is the unbounded-list trap again. Decline the
  curtain, and note what it means: the gateway's blast radius is bounded by its *route table*, not by
  its netpol.
- **`monitoring` egress.** Prometheus is a client by construction; its hole list is every scraped
  namespace plus the pod CIDR, kubelet `:10250`, the node IPs and the API server, and it grows
  whenever an exporter appears. One object with an unbounded, mutating hole list is worse than the
  fall-through it replaces — rule 3's reader-cost argument points the other way here. Monitoring's cost
  lands on the *scraped* namespaces instead: each one's ingress curtain has to name it, already paid
  once in `longhorn-manager-metrics-ingress`.
- **`media`'s `self` rule stays.** Replacing the namespace profile's `self` with enumerated
  in-namespace `egress_peer`s was the open "item 1"; rule 3 declines it — it trades one readable object
  for a list nobody will re-read. Accepted consequence, named rather than hidden: every pod in `media`
  reaches every other pod there on any port, `9113` and `9000` included. If that ever matters, the NGF
  control plane is a rule-4 *mirror* case that **is** expressible today — a pod-scoped ingress policy
  on it narrows hard, unlike `longhorn-manager`, which a namespace-wide curtain would swallow.
- **`kube-network-vpn`** is wireguard on the host network: no namespaced policy reaches it, ever. Same
  for `blender`'s mDNS advertiser, `calico-node` and `metallb-speaker` — the "limits to name" in
  `modules/network/firewalls/README.md`.
- **`ai`, `calico-system`, `kube-system`** are not this repo's to police.
- **`longhorn-system` egress** is not rule-driven: longhorn is at-risk-*from*, not risky-to, and its
  dialers are the apiserver, node IPs and peer engines — most of the cluster. Do it last, or never, and
  say which.

**Two module gaps, recorded not hidden** (`modules/network/firewalls/README.md`):
`to_namespaces` grants a whole namespace on **every** port — the narrow
`namespace + pod selector → :9000` form the outposts used to have is not expressible, so media's
outpost holds a wider grant than it uses; and the LAN is only reachable as an explicit
`to_cidrs` value each caller has to be handed (`var.deployment.network.host_cidr` is the only
declaration of it), with no helper for node addresses either.

## This memory bank was restored, not written (2026-09-17)

All six files came back from git: `306d5e7 wipe the memory` and `b1be450` had deleted them
(`306d5e7^` holds the last full versions — 313-line `activeContext`, 740-line `progress`).
What changed against that recovered text is only what the rebuild invalidated: the
`no network-policy layer` pattern, the two bullets above that had been declared moot, the chart
pin list (everything is pinned now), and the toolchain versions. `.clinedocs/calico-netpols.md`
was restored the same way, because three live docs (`modules/network/README.md`,
`modules/network/firewalls/README.md`, `modules/network/whisker/tier.tf`) plus
`.clinerules/resources.md` point at it.

Wanted, and a prerequisite for nothing: the **per-pod flow table for namespaces whose curtain has
landed** — i.e. the hole list. Reading it *is* how the holes get named (`.clinedocs/flow-logs.md`;
Whisker is already port-forwarded in the recipes), but a table built before the curtain exists
measures the fall-through, not the profile. Tool, not gate.

## Open items with no home elsewhere

- **Harbor's `linuxguru` project has zero consumers** (0 artifacts); dropping it from
  tfvars destroys it, so it stayed pending a call. `library` (Harbor's default, public)
  is deliberately *not* in `var.deployment.harbor.projects`.
- **`default/jblack`** is the one CA-era secret deliberately left (only one with
  *client-auth* EKU, `SAN DNS:jblack`, exp 2026-12-03) so an off-cluster mTLS client may
  still use it. Its Certificate CR is gone, so it will never renew — delete when sure.

## Durable facts and quirks

- **"SeaweedFS is fine" is not a question `up{}` answers** (recipe verified 2026-09-17). Its exporter's
  metric names are **`SeaweedFS_*` with a capital S** — leader/layout (`is_leader`, `leader_changes`,
  `volume_layout_crowded`), volume health (`read_only_volumes`, `io_quarantine`, `disk_error_status`,
  `storage_io_error_total`, `file_read_failures`, `file_write_failures`), EC vacuum, and
  `s3_bucket_object_count`/`_size_bytes` per bucket. `up` was 13/13 the whole time
  `master_pick_for_write_error` climbed (~2–5/6h, pre-dating the ingress policy — open item in
  `progress.md`). For the data path, the proof is a write through a mounted RWX share plus a **sha256
  read-back from a pod on another node** — same node and the page cache answers instead of the volume
  server; the same PVC is mounted at different paths per app (`/movies`, `/media`, `/downloads`), so a
  reader that "cannot see" the file is usually just looking in the wrong path.

- **Route53 is the public authority for the whole `linuxguru.net` tree.**
  `vn.linuxguru.net` has no NS delegation, so an ACME TXT written into `Z3FM4Y4P2572E4`
  is what Let's Encrypt sees; bind9 stays the LAN-only view. Verified 2026-09-15
  **against the API, not dig**: the zone holds no `.vn` records at all, and every `.vn`
  name resolves publicly only because `*.linuxguru.net` is an **A alias to
  `home.linuxguru.net`** applied at any depth. (Earlier notes claiming a real
  `*.vn.linuxguru.net` record were wrong — dig can't tell a record from synthesis.)
- **Issuer plumbing is one key:** `cert_authorities.default` (= `letsencrypt`), read as
  a plain `cert_issuer` string per module. Host count: **19 Certificates live, 16
  declared in this repo** — `ollama`, `llm-embedder`, `corsless` come from the external
  app-of-apps repo.
- **`stacks/apps` has no `terraform.tfvars` symlink** — it needs
  `-var-file=~/.tfenvs/k8s.tfenv` explicitly.
- **The tfvars files are symlinks** (git mode `120000`) into `~/.tfenvs/`, i.e. outside
  the repo, and **`grep -r` does not follow symlinked files** — the trap that hid dead
  keys (`deployment.keycloak`, `deployment.ldap`, `argocd_devops.repo_name`,
  `argocd_devops.harbor_project`; backup at `~/.tfenvs/k8s.tfenv.bak-20260915`). See
  `techContext.md`.
- **Route53 credentials are NOT in git** — the access key appears nowhere in history
  (`git log --all -S` → empty) nor in any tracked blob (`git grep AKIA HEAD` → empty),
  because the tfvars are symlinks. Rotating is still fine hygiene (it is the DNS-01
  credential).
- **`harbor.${var.domain}/library` is the registry the ai apps use and it is NOT
  TF-managed** (Harbor's default project, public). The old `linuxguru` registry name was
  a **split-brain**: charts, Argo repo URL and TF said `linuxguru`, artifacts went to
  `library`, and `robot$jblack` has a system permission on `library` only →
  `404: repository linuxguru/… not found`. Import `library` before adding any
  `harbor_project` resource or `apply` 409s. `argocd_repository`'s **id is the repo
  URL** — a stale URL makes every mantle plan report `1 to add`.
- **Argo CD has no webhook** (no `webhook.*.secret`, no `argocd-cm` key), so an
  external-repo push triggers only on the poll (`timeout.reconciliation: 180s`). Force
  it: `kubectl -n argo annotate application aoa-ai argocd.argoproj.io/refresh=hard
  --overwrite` — the **root** app, not the child (the child's spec is generated).
- **Verifying a host's TLS:** check the wire, not the sync status
  (`openssl s_client … | openssl x509 -noout -issuer -dates`) and that a stock-trust
  `curl` (no `--cacert`) validates it, i.e. `ssl_verify_result=0` on system roots alone.

- **Building/pushing the ai apps from a fresh machine** (app-of-apps repo
  `~/code/k8s/argocd`):
  - helm's registry store on macOS is `~/Library/Preferences/helm/registry/config.json`,
    **not** `~/.config/helm/…`; missing ⇒ anonymous `helm push` ⇒ `401`.
  - a Dockerfile that builds for the builder's platform yields a qemu-emulated image
    that crashes; use `FROM --platform=$BUILDPLATFORM` + `GOOS`/`GOARCH`.
  - a chart's stock `helm create` Ingress (`className: private`) attaches to nothing
    here — the gateways serve HTTPS only via app-declared ListenerSets, so it dies with
    `unrecognized name` and Argo sits `Progressing` (an Ingress never gets an address).
  - `llm-embedder`'s Dockerfile: `--index-url` against the CPU wheel index is exclusive
    and carries no build deps, so pip fell back to the sdist and lost `flit_core`. Fix:
    `--extra-index-url https://pypi.org/simple` plus an explicit `torch==2.8.0+cpu`, so
    PyPI's CUDA build can never win.
  - the live Argo repo Secret is `argo/repo-3272614039` (`url=…/library`,
    `enableOCI=true`), and the chart version is a `0.0.*` wildcard, so a republished
    chart auto-syncs.
  - re-verify through the gateway: `/health` →
    `{"name":"llm-embedder","status":"ok"}`,
    `/embed?text=hello+world&prompt=retrieval.query` → **200, 1024-dim**; corsless
    `/health` → `200 {"status":"ok"}`, proxied calls carry `access-control-allow-origin: *`.
- **Argo Workflows' SSO entry point on this chart is `/oauth2/redirect`**;
  `/oauth2/start` just returns the SPA (200) and looks like a failure. Cheap OIDC check
  for all four: argo-cd `/auth/login`, grafana `/login/generic_oauth`, harbor
  `/c/oidc/login` and argo-wf `/oauth2/redirect` must all 302 to
  `https://auth.vn.linuxguru.net/application/o/authorize/` with the right `client_id`;
  an in-cluster `curlimages/curl` probe then shows whether `auth.vn` validates on system
  roots alone, no browser needed.
- **Trust graph facts** (enumerated 2026-09-15): `kube-apiserver` has **no** `--oidc-*`
  flags; authentik outposts talk plain HTTP in-cluster and never validate `auth.vn` TLS
  (`browser_url` is redirect-only); node trust is *additive* (`initial_setup.yml` copies
  the CA into `/usr/local/share/ca-certificates/` + `update-ca-certificates`; the
  containerd `certs.d` override covers only `docker.io`); Harbor's OIDC config lives in
  Harbor's **DB** (`harbor_config_auth`), invisible to grep; `authentik-server`/`worker`
  mount `cert-auth.vn…` so they need a **rollout** after an issuer flip; no live client
  certs come from the CA.
- **There is no `TODO.md`** — open work lives in `progress.md` and this file. All six
  docs that pointed at it were repointed 2026-09-15.
- The vaultwarden build shipped and was verified live 2026-09-14; its 33 KB handoff doc
  was retired into `modules/vaultwarden/README.md` and
  `modules/network/dns/route53_record/README.md`.
- **Environment gotcha:** when this Mac's resolver (`192.168.0.2`) drops out mid-run,
  plans abort with `charts.jetstack.io: no such host` and an STS
  `lookup sts.us-west-2.amazonaws.com` failure. Not config — re-run once DNS recovers
  and it plans `No changes`. That outage is the one justified use of `-target` (the 3+6
  ListenerSets).


## Settled — don't relitigate

- Three stacks, applied in order (core → mantle → apps); state in k8s Secrets.
- `cert_authorities.default` is the one issuer knob; no per-app override maps.
- Typed `kubernetes_*` resources over `kubectl_manifest`, so `plan` sees drift.
- Terraform owns groups/apps/bindings; the authentik UI owns membership.
- No `-target` / `-exclude`.
- **The firewall frame: a namespace-scoped curtain first, then holes** — one direction or both, chosen
  by which way the namespace is dangerous. Risky **to** the cluster → drop egress (`media`). At risk
  **from** the cluster → drop ingress (`kube-storage`, `longhorn`). Self-talk stays open, and one
  namespace is **one object** — the reader's working set is the constraint, not the object count. A pod
  worse than its namespace (plex, qbittorrent; `longhorn-manager-metrics-ingress`) is carved out of the
  namespace's holes and given its own. Ordering between our own policies doesn't matter — they union in
  tier `default` — and a brief cutover outage is acceptable. The direction may differ per namespace, and
  a namespace may eventually carry both. Whisker's tier CRs are the exception that is not an exception:
  they exist so the operator's own tier stops breaking whisker. Full rule of thumb:
  `modules/network/firewalls/README.md`.
- Parse the **narrowest doc first**: root README → module README → `.clinedocs/`.
- **Code comments: rare, one line max, only for the most important details and traps**
  (rule lives in `.clinerules/behavior.md`, loaded every session). Swept repo-wide 2026-09-17
  (982 → 616 lines). The one sanctioned exception is a **≤4-line file header** — a deliberate call,
  not an oversight, so **don't re-sweep the headers down to a literal single line**.

## Reading order for a fresh session

1. Root `README.md` (map, hostnames, conventions).
2. `memory-bank/progress.md` (what's actually open).
3. The `README.md` of the one module you're touching.
4. `.clinedocs/calico-netpols.md` or `.clinedocs/flow-logs.md` only for a
   NetworkPolicy / flow-query task.

