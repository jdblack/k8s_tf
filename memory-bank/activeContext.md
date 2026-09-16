# Active Context

*Consolidated 2026-09-16; **updated later that day — the firewall layer was deleted**.
State and in-flight work; the open list is `progress.md`.*

## Current state

- **There is no network-policy layer any more (deleted 2026-09-16).**
  `modules/network/firewalls/` (the `policy` renderer + `basic_egress` +
  `limited_ingress`), every per-app `security.tf`, and all the wiring that fed them
  (the per-module `api_peer_ips`/`lan_cidrs`/`system_namespace`/`enable_egress_firewall`
  variables, `data.kubernetes_endpoints_v1.kubernetes` + `local.api_peer_ips` in
  `stacks/core/core.tf`, whisker/seaweedfs_admin's `firewalls` module calls,
  `network/gateway`'s `cert_generator_job_name` output) are gone, so every workload can
  reach every other one. **Kept on purpose:** `modules/network/whisker/tier.tf` — 3 Calico
  CRs at `spec.tier: calico-system`, which are not a restriction but the thing that makes
  whisker work at all (the operator's tier denies that namespace outright). Post-mortem
  invariants for any future policy work: `.clinedocs/calico-netpols.md`; the removal
  record and what to expect on the first apply: `progress.md`.
- Branch `main`, **ahead of `origin/main`, not pushed** (`5f0f582` → `226ba04` →
  `bbe94f4` → `985c334` → the 2026-09-16 sweep, five commits: pin/bump backlog, whisker
  Calico tier, authentik signing key, NGF hook egress, docs).
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
- **The NGF cert-generator hook needed an API carve-out while netpols existed — now moot
  (2026-09-16).** The media gateway's helm upgrade once hung `Still modifying [id=ngf]`
  (`pending-upgrade`) because its `cert-generator` Job pods `Error`-looped on
  `dial tcp 10.96.0.1:443: i/o timeout`: a **Job's pods carry only the Job controller's
  labels** (`job-name`, …), never the chart's `app.kubernetes.io/name`, so a pod-scoped
  policy keyed on that label missed them. Policy and the `cert_generator_job_name` output
  are deleted with the firewall layer, so there is nothing to do today — but that label
  rule is why any future pod-scoped netpol must special-case Job traffic.
- **Longhorn snapshots are one cluster-wide, TF-owned scheme and the restore path is
  verified end to end.** Jobs, enrolment table and the label trap: `progress.md` and
  `modules/storage/longhorn_jobs.tf`. Verified on throwaway objects: a revert is refused
  while attached *and* while detached; patching the VolumeAttachment ticket's
  `parameters.disableFrontend` works (no detach needed) and restored data really is
  pre-snapshot. **The manager API is in-cluster only:** `kubectl exec` into a
  `longhorn-manager` pod + `http://longhorn-backend:9500` (port-forward and the apiserver
  service-proxy both fail). **No `backupTarget`: recovery, not backup.**
- **The core-apply "inconsistent final plan" landmine died with the layer (2026-09-16).**
  A pending change in any module under a caller's `depends_on` deferred the `kubernetes`
  Endpoints read that used to live *inside* the authentik policy module, so the plan's `to`
  block count was a guess and the apply aborted. The fix (read it in the stack root, pass
  the peer IPs down as `api_peer_ips`) has been deleted along with the policy — the
  mechanism is generic and still worth knowing: `.clinedocs/calico-netpols.md`; evidence:
  `progress.md`.
- **The CA migration is finished: all 17 hosts are on Let's Encrypt and nothing consumes
  `linuxguru-ca`** (dormant, not deleted; `var.ca_certfile`/`ca_keyfile` remain a standing
  **plan-time** dependency of `stacks/core`). Checklist:
  `modules/cert_manager/README.md`.

## The policy layer was thrown away (2026-09-16), not parked

The namespace-ingress rollout that used to be the main thread of work here (staged policies
→ soak → enforce, `media` as the model) is **cancelled**, and its output went with it:
`media` was locked down 2026-09-12, and four days later every policy in the repo was
deleted. Nothing here enforces network policy today except whisker's tier CRs.

The method is not lost if it is ever restarted: `.clinedocs/calico-netpols.md` keeps the
invariants (post-DNAT egress, netpols only UNION, tier ordering, the Job-label gotcha) and
`.clinedocs/flow-logs.md` keeps the Goldmane/Whisker queries for deriving a guest list from
**real traffic instead of guesses**. Two lessons from the first attempt:

- **Staging previews only where the staged policy is the deciding one** — a namespace with
  any permissive netpol just unions and previews nothing.
- **Put the `staged` flag in code from day one.** The first attempt proved the mechanism by
  hand and never implemented it, so every candidate namespace had to be fenced blind.

## Open items with no home elsewhere

- **Harbor's `linuxguru` project has zero consumers** (0 artifacts); dropping it from
  tfvars destroys it, so it stayed pending a call. `library` (Harbor's default, public)
  is deliberately *not* in `var.deployment.harbor.projects`.
- **`default/jblack`** is the one CA-era secret deliberately left (only one with
  *client-auth* EKU, `SAN DNS:jblack`, exp 2026-12-03) so an off-cluster mTLS client may
  still use it. Its Certificate CR is gone, so it will never renew — delete when sure.

## Durable facts and quirks

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
- Parse the **narrowest doc first**: root README → module README → `.clinedocs/`.

## Reading order for a fresh session

1. Root `README.md` (map, hostnames, conventions).
2. `memory-bank/progress.md` (what's actually open).
3. The `README.md` of the one module you're touching.
4. `.clinedocs/calico-netpols.md` or `.clinedocs/flow-logs.md` only for a
   NetworkPolicy / flow-query task.

