# Active Context

*Last consolidated 2026-09-16. The dated blow-by-blow is folded into one-line
entries at the bottom; `progress.md` holds the open list.*

## Current state

- Branch `main`, **ahead of `origin/main`, not pushed** (`5f0f582` → `7c24e81` →
  `92469da` → `226ba04` → `bbe94f4` → the 2026-09-15/16 sweeps).
- **VIP policy: everything floats, names are the interface.** No address is
  pinned in tfvars — clients find services by *DNS*, so every gateway/LB takes a
  MetalLB pool VIP. `gateway_ips` is deleted from `modules/network` (with it
  tfvars `network_ingress` and the `stacks/core/core.tf` argument, its only
  consumers), both shared gateways float, `qbittorrent_torrent_lb_ip` is unset
  (variable kept as the re-pin escape hatch), and vaultwarden's Route53 A record
  reads the private gateway's live data-plane Service
  (`kubernetes_service_v1` data source in `stacks/mantle/vaultwarden.tf`).
  Consequence to remember: MetalLB keeps an assigned IP when
  `spec.loadBalancerIP` is cleared, but a **recreated** Service gets a different
  pool IP — the two router NAT rules (WAN 443 → public gateway, WAN 21010 →
  torrent) are the only things needing attention, and only on a recreate.
  Plans: core 0/17/2, mantle 0/10/0, in-place, **not applied**.
- **All 28 `moved` blocks are deleted** — every one was spent (17 files, three
  refactors: `expose`, `firewalls/policy`, the authentik group's brief `count`).
  Proof: `state list` holds only destination addresses, and both stacks plan
  **No changes** after deletion (`apps` can't plan without its `deployment`
  var; none of its 4 resources were affected). **Rule:** a `moved` block dies in
  the same change that applies it. The shape to re-add, with rationale, is in
  `modules/network/gateway/expose/README.md`.
- **Longhorn snapshots are one cluster-wide, TF-owned scheme, and the restore
  path is verified end to end.** `modules/storage/longhorn_jobs.tf` owns three
  jobs (daily 03:00, weekly Sun 04:00, monthly 28th 05:00, UTC, uniform
  `retain: 2`) plus the enrolment table (8 volumes covered, 7 explicit `skip`);
  `snapshot_labeler.tf` writes the group labels onto the **Volume CRs** and is
  the only writer of them. The per-app job in `modules/vaultwarden/backup.tf` is
  retired. Verified on throwaway objects: the join fires from a Volume-CR label
  alone; a new volume is born in the `default` group; revert is refused
  (`failed to revert snapshot ... with frontend enabled`, http 500) while
  attached **and** while detached; patching the Volume CR's `disableFrontend` is
  reverted by the controller, patching the VolumeAttachment ticket's
  `parameters.disableFrontend` works (no detach needed), the revert returns 200
  and the remounted data really is the pre-snapshot content; the no-ticket path
  (`attach` + `attacherType: longhorn-api` + `disableFrontend: true`) works too.
  **The manager API is in-cluster only**: `kubectl exec` into a
  `longhorn-manager` pod + `http://longhorn-backend:9500` (port-forward and the
  apiserver service-proxy both fail). Runbook + coverage audit:
  `modules/storage/disaster_recovery.md`, mirrored per consumer (vaultwarden,
  auth/authentik/core, monitoring/prometheus, harbor/core, storage/seaweedfs,
  storage/seaweedfs_admin, media/prowlarr, media/bazarr). **Still no
  `backupTarget`: this is recovery, not backup.**
- **The core-apply landmine is fixed.** A pending change in any module under a
  caller's `depends_on` (cert-manager as readily as storage) deferred the
  `kubernetes` Endpoints read inside authentik's `allow_api` netpol and the
  apply aborted with a provider "inconsistent final plan" error. The read now
  happens in the stack root (`stacks/core/core.tf`) and is passed down as
  `api_peer_ips`. Mechanism: `.clinedocs/calico-netpols.md`; evidence:
  `progress.md`.
- **The CA migration is finished: all 17 hosts are on Let's Encrypt and nothing
  consumes `linuxguru-ca`.** The last four (`auth.vn`, `harbor`, `grafana`,
  `argo-wf`) flipped in one apply per stack together with the deletion of every
  CA injection (core 0/5/2, mantle 0/3/1); `ollama.vn` flipped in the external
  app-of-apps repo. The CA is **dormant** but not deleted, and
  `var.ca_certfile`/`ca_keyfile` remain a standing **plan-time** dependency of
  `stacks/core` — full story, expiry and re-introduction checklist in
  `modules/cert_manager/README.md`.

## In flight

**Namespace ingress rollout, part 2** — the "media treatment" for the remaining
namespaces. Media is the **only** namespace with enforced NetworkPolicies
(locked down 2026-09-12); everything else is open to any cluster pod. Method
(validated by hand, not yet in code): render staged policies via a `staged` flag
on `firewalls/policy` (+ pass-through on `limited_ingress`), stage → watch a few
days with real traffic (a login, an Argo sync, a fresh image pull) → flip
`staged = false`.

- The staged mechanism is **proven** (an allow-list staged on `argo` logged
  `pendingPolicies: Deny` while traffic kept flowing) but **the `staged` flag
  does not exist in code yet** (grep-verified 2026-09-14) — implementing it is
  the first concrete task.
- Guest lists were never written down (the `TODO.md` they pointed at does not
  exist); derive them from Goldmane/Whisker flow data, not guesses.
- Highest-value first candidates: `kube-auth`, `devops-harbor`, `argo`, `ai`,
  `monitoring`, `kube-certificates`, `blender`.
- `argo` also has **no egress fence** (`enable_egress_firewall=false`).

## Owed follow-ups (the old `TODO.md` list)

- **Backups are cluster-local for *every* volume** → point Longhorn
  `backupTarget` at the SeaweedFS S3 endpoint and add/flip jobs to
  `task = "backup"`. Until then treat the cluster as one failure domain and
  export vaultwarden from a client before any destroy.
- **Nothing scrapes cert-manager.** No `ServiceMonitor`, no expiry
  `PrometheusRule`, so a failed renewal is invisible until the cert expires
  (~30 days of slack, since renewal is at 2/3 of lifetime). Cheap win: a
  ServiceMonitor on `kube-certificates/cert-manager:9402` plus a
  `certmanager_certificate_expiration_timestamp_seconds < 21d` alert.
- **Longhorn has no Grafana dashboard** — ship it the SeaweedFS way, next to
  `modules/storage/longhorn.tf`.
- **Whisker UI**: confirm the flow list populates *through the authentik proxy*.
- **external-dns never published `certtest.vn.linuxguru.net`** from its HTTPRoute
  annotation — understand why before relying on automatic `.vn` DNS.
- **Harbor's `linuxguru` project has zero consumers** (0 artifacts); dropping it
  from tfvars destroys it, so it is still there pending a call. `library` (the
  Harbor default, public) is deliberately *not* in
  `var.deployment.harbor.projects` — TF only needs its *name* to build the OCI
  URL.
- **`default/jblack`** is the one CA-era secret deliberately left (only one with
  *client-auth* EKU, `SAN DNS:jblack`, exp 2026-12-03), so an off-cluster mTLS
  client may still use it. Its Certificate CR is gone, so it will never renew —
  delete when you're sure.
- **`corsless` / `llm-embedder`** are dead apps for a different reason now
  (`404: repository linuxguru/corsless-helm not found`, i.e. the registry
  split-brain), not TLS.

## Durable facts and quirks

- **Route53 is the public authority for the *whole* `linuxguru.net` tree.**
  `vn.linuxguru.net` has no NS delegation, so an ACME TXT written into
  `Z3FM4Y4P2572E4` is what Let's Encrypt sees; bind9 stays the LAN-only view.
  Verified 2026-09-15 **against the API, not dig**: the zone holds no `.vn`
  records at all, and every `.vn` name resolves publicly only because
  `*.linuxguru.net` is an **A alias to `home.linuxguru.net`** applied at any
  depth. (Earlier notes claiming a real `*.vn.linuxguru.net` record were wrong —
  dig can't tell a record from synthesis, and the stale `4.5.7.6`-style answer
  was a deletion still propagating.)
- **Issuer plumbing is one key:** `cert_authorities.default` (= `letsencrypt`),
  read as a plain `cert_issuer` string per module. The per-app override maps, the
  `local.issuers` indirection, the seaweedfs visibility map, the `merge()` in
  `stacks/core/storage.tf` and the dead `cert.pub_cert_issuer` key are gone
  (empty plans before *and* after proved they were the same constant).
  Host count: **19 Certificates live, 16 declared in this repo** — `ollama`,
  `llm-embedder`, `corsless` come from the external app-of-apps repo.
- **`stacks/apps` has no `terraform.tfvars` symlink** — it needs
  `-var-file=~/.tfenvs/k8s.tfenv` explicitly. Its clean plan on 2026-09-15 was
  the **first drift check since August**.
- **The tfvars files are symlinks** (git mode `120000`) into `~/.tfenvs/`, i.e.
  outside the repo, and **`grep -r` does not follow symlinked files** — the trap
  that hid dead keys (`deployment.keycloak`, `deployment.ldap`,
  `argocd_devops.repo_name`, `argocd_devops.harbor_project`; backup at
  `~/.tfenvs/k8s.tfenv.bak-20260915`). See `techContext.md`.
- **Route53 credentials are NOT in git.** The access key (begins `AKIA…`) appears
  nowhere in history (`git log --all -S` → empty) nor in any tracked blob
  (`git grep AKIA HEAD` → empty), because the tfvars are symlinks. Exposure is a
  plaintext file on local disk — the intended single-sourced design. Rotating is
  still fine hygiene (it is the DNS-01 credential).
- **`harbor.${var.domain}/library` is the registry the ai apps use, and it is
  NOT TF-managed** (Harbor's default project, public). The old `linuxguru`
  registry name was a **split-brain**: charts, Argo repo URL and TF said
  `linuxguru`, but artifacts went to `library` and `robot$jblack` only has a
  system permission on `library` → `404: repository linuxguru/… not found`.
  Decision: point the apps at `library`, not widen the robot. Import it before
  adding any `harbor_project` resource or `apply` 409s. `argocd_repository`'s
  **id is the repo URL** — a stale URL makes every mantle plan report `1 to add`.
- **Argo CD has no webhook** (no `webhook.*.secret`, no `argocd-cm` key), so an
  external-repo push triggers only on the poll (`timeout.reconciliation: 180s`).
  Force it:
  `kubectl -n argo annotate application aoa-ai argocd.argoproj.io/refresh=hard --overwrite`.
  Refresh the **root** app (`aoa-ai`), not the child — the child's whole spec is
  generated by the root. Verify the wire, not the sync status
  (`openssl s_client … | openssl x509 -noout -issuer -dates`), and that a
  stock-trust `curl` (no `--cacert`) validates it, i.e. `ssl_verify_result=0`
  on system roots alone.
- **Reaching a service from a fresh machine (ai apps, 2026-09-15).** The
  app-of-apps repo is `~/code/k8s/argocd` (both apps repointed there: chart
  `values.yaml` + `deployments/ai/*.yaml`):
  - helm's registry store on macOS is
    `~/Library/Preferences/helm/registry/config.json`, **not**
    `~/.config/helm/…`; missing ⇒ anonymous `helm push` ⇒ `401`.
  - a Dockerfile that builds for the builder's platform yields a qemu-emulated
    image that crashes; use `FROM --platform=$BUILDPLATFORM` + `GOOS`/`GOARCH`.
  - a chart's stock `helm create` Ingress (`className: private`) attaches to
    nothing here — the shared gateways serve HTTPS only, via app-declared
    ListenerSets, so it dies with `unrecognized name` and Argo sits
    `Progressing` (an Ingress never gets an address).
  - `llm-embedder`'s Dockerfile also needed a fix: torch went in with
    `--index-url` (exclusive) against the CPU wheel index, which carries no
    build deps — pip rejects PyPI's `typing_extensions` wheel ("inconsistent
    Name"), falls back to the sdist and can't find `flit_core` there. Fix:
    `--extra-index-url https://pypi.org/simple` plus an explicit
    `torch==2.8.0+cpu`, so PyPI's CUDA build can never win.
  - the split-brain's provenance: `AppInfo.txt` pushed to `library` while
    values, Argo and TF all said `linuxguru`; the live Argo repo Secret is
    `argo/repo-3272614039` (`url=…/library`, `enableOCI=true`), and the chart
    version is a `0.0.*` wildcard, so a republished chart auto-syncs.
  - re-verify an app through the gateway: `/health` →
    `{"name":"llm-embedder","status":"ok"}`, and
    `/embed?text=hello+world&prompt=retrieval.query` → **HTTP 200, 1024-dim**;
    corsless `/health` → `200 {"status":"ok"}` and proxied calls carry
    `access-control-allow-origin: *`.
- **Argo Workflows' SSO entry point on this chart is `/oauth2/redirect`;**
  `/oauth2/start` just returns the SPA (200), which looks like a failure and
  isn't. The cheap OIDC check for all four is a redirect trace: argo-cd
  `/auth/login`, grafana `/login/generic_oauth`, harbor `/c/oidc/login` and
  argo-wf `/oauth2/redirect` all 302 to
  `https://auth.vn.linuxguru.net/application/o/authorize/` with the right
  `client_id`; an in-cluster `curlimages/curl` probe of any of them shows
  whether `auth.vn` validates on system roots alone (`ssl_verify_result=0`)
  without a browser.
- **Trust graph facts** (enumerated 2026-09-15): `kube-apiserver` has **no**
  `--oidc-*` flags; authentik outposts talk plain HTTP in-cluster and never
  validate `auth.vn` TLS (`browser_url` is redirect-only); node trust is
  *additive* (`initial_setup.yml` copies the CA into
  `/usr/local/share/ca-certificates/` + `update-ca-certificates`, and the
  containerd `certs.d` override covers only `docker.io`); Harbor's OIDC config
  lives in Harbor's **DB** (`harbor_config_auth`), invisible to grep;
  `authentik-server`/`worker` mount `cert-auth.vn…` so they need a **rollout**
  after an issuer flip; no live client certs come from the CA
  (`~/code/k8s/projects/openvpn-docker` builds CRs but only WireGuard is
  deployed).
- **There is no `TODO.md`** — open work lives in `progress.md` and this file.
  Six docs pointed at it anyway (root README, `.clinerules/resources.md`,
  `.clinedocs/flow-logs.md`, `modules/{media,vaultwarden}/README.md`, the
  reading order) — all repointed 2026-09-15.
- The vaultwarden build shipped and was verified live 2026-09-14; the 33 KB
  handoff doc was retired into `modules/vaultwarden/README.md` and
  `modules/network/dns/route53_record/README.md`.
- **Environment gotcha:** when this Mac's resolver (`192.168.0.2`) drops out
  mid-run, plans abort with `charts.jetstack.io: no such host` and an STS
  `lookup sts.us-west-2.amazonaws.com` failure. Not config — re-run once DNS
  recovers and it plans `No changes`. That outage is the one justified use of
  `-target` (the 3+6 ListenerSets).

## Settled — don't relitigate

- Three stacks, applied in order (core → mantle → apps); state in k8s Secrets.
- `cert_authorities.default` is the one issuer knob; no per-app override maps.
- Typed `kubernetes_*` resources over `kubectl_manifest`, so `plan` sees drift.
- Terraform owns groups/apps/bindings; the authentik UI owns membership.
- No `-target` / `-exclude`.
- Parse the **narrowest doc first**: root README → module README → `.clinedocs/`.

## Recent history, one line each

- **2026-09-16** — every `*.tf` comment trimmed to constraints/gotchas only
  (history, dates, README pointers and rationale dropped). `tofu fmt -recursive
  -check` clean, `validate` green in all three stacks; the pass had also eaten
  `variable "private_gateway_ip"` in `modules/vaultwarden/variables.tf` — found
  by `validate`, restored. See `progress.md` → Traps.
- **2026-09-16** — VIP pins removed (everything floats; DNS is the interface).
- **2026-09-16** — all 28 `moved` blocks deleted (all spent); Longhorn snapshot
  scheme centralised and the restore path verified.
- **2026-09-15** — CA migration finished, 17/17 on Let's Encrypt; CA dormant.
- **2026-09-15** — issuer plumbing collapsed onto `cert_authorities.default`
  (no-op plan proved it).
- **2026-09-15** — both `ai` apps un-broken: platform-cross-compile, helm
  registry auth path, registry split-brain → `library`, ListenerSet exposure.
  `llm-embedder`'s `/embed` 500 was a task-name typo (`retrival.query`), fixed in
  `0.0.79`. Note `prompt` is accepted but **ignored** — `EmbedService.embedding()`
  hardcodes `retrieval.query`, so a passage-side caller can't ask for
  `retrieval.passage` (real design gap, not a bug).
- **2026-09-15** — IdP-first login (gateway hijack of `Exact /`) tried, judged
  not worth its failure mode, removed: it looped when the target lacked a return
  URL, 604 log lines in 3h **all `level=info`**, nothing visible in a plan. Both
  apps serve their own login page again and `redirect_route` is deleted; the
  one-click paths (`/auth/login`,
  `/oauth2/redirect?redirect=/workflows`) still work for bookmarks. No native
  switch exists for either app, so IdP-first there is a facade by construction.
- **2026-09-15** — orphan sweep: `letsencrypt-http` ClusterIssuer + its account
  key deleted (HTTP-01 leftover, no Certificate referenced it — do not confuse
  them with the live `certman-letsencrypt` /
  `certman-route53-letsencrypt` solver secrets); CA-era secrets `ai/cert-ollama`,
  `argo/argocd-server-tls`, `monitoring/prometheus-grafana-cert`,
  `kube-auth/keycloak.vn.linuxguru.net-tls` (expired 2026-02-04) deleted;
  `kube-security` ns, the orphaned `tfstate-default-fuckbatz` Secret,
  `trivy-system`/`trivy-temp` and the fuckbatz lock Lease all deleted. Secrets
  are not Terraform state, so none of this moved a plan.
- **2026-09-15** — `ai` namespace dual ownership fixed: core created it *and*
  `stacks/apps`'s `aoa_deployment` did, so destroying either stack would have
  taken it out from under the other. Core released it (`state rm` **first**, then
  the file — so no plan could destroy the live namespace); apps keeps ownership.
- **2026-09-15** — dead config deleted after a `grep`-verified audit:
  `deployment.keycloak`, `deployment.ldap`, `argocd_devops.repo_name`,
  `argocd_devops.harbor_project` (the tfenv is not under git); the `fuckbatz`
  WordPress module was deleted outright (`notbatz.com` is not a Route53 zone in
  this account — only `linuxguru.net` and `emtho.com` are — so the site could
  never resolve); `.terraform` caches pruned 2.5 GB → 1.5 GB (only versions
  absent from each stack's lock file, plus unreferenced module dirs).

## Reading order for a fresh session

1. Root `README.md` (map, hostnames, conventions).
2. `memory-bank/progress.md` (what's actually open).
3. The `README.md` of the one module you're touching.
4. `.clinedocs/calico-netpols.md` or `.clinedocs/flow-logs.md` only for a
   NetworkPolicy / flow-query task.



