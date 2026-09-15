# Active Context

*Consolidated 2026-09-16. State and in-flight work; the open list is `progress.md`.*

## Current state

- Branch `main`, **ahead of `origin/main`, not pushed** (`5f0f582` → `226ba04` →
  `bbe94f4` → the 2026-09-15/16 sweeps).
- **VIP policy: everything floats, names are the interface.** `gateway_ips` is deleted
  from `modules/network` (with tfvars `network_ingress` and the `stacks/core/core.tf`
  argument, its only consumers); `qbittorrent_torrent_lb_ip` is unset (variable kept as
  the re-pin escape hatch); vaultwarden's Route53 A record reads the private gateway's
  live data-plane Service (`kubernetes_service_v1` data source in
  `stacks/mantle/vaultwarden.tf`). MetalLB keeps an assigned IP when
  `spec.loadBalancerIP` is cleared, but a **recreated** Service gets a different pool IP
  — so only the two router NAT rules (WAN 443 → public gateway, WAN 21010 → torrent) ever
  need re-pointing, and only on a recreate. Plans: core 0/17/2, mantle 0/10/0, in-place,
  **not applied**. Unpinning evidence + current assignments: `progress.md`.
- **All 28 `moved` blocks are deleted** — every one was spent, and both stacks plan
  **No changes** without them. Rule and per-refactor detail: `progress.md` → Traps.
- **Longhorn snapshots are one cluster-wide, TF-owned scheme and the restore path is
  verified end to end.** Jobs, enrolment table and the label trap: `progress.md` and
  `modules/storage/longhorn_jobs.tf`. Verified on throwaway objects: a revert is refused
  while attached *and* while detached; patching the VolumeAttachment ticket's
  `parameters.disableFrontend` works (no detach needed) and restored data really is
  pre-snapshot. **The manager API is in-cluster only:** `kubectl exec` into a
  `longhorn-manager` pod + `http://longhorn-backend:9500` (port-forward and the apiserver
  service-proxy both fail). **No `backupTarget`: recovery, not backup.**
- **The core-apply landmine is fixed (2026-09-16).** A pending change in any module under
  a caller's `depends_on` deferred the `kubernetes` Endpoints read inside authentik's
  `allow_api` netpol and the apply aborted with a provider "inconsistent final plan"
  error; the read now happens once in the stack root and is passed down as
  `api_peer_ips`. Mechanism: `.clinedocs/calico-netpols.md`; evidence: `progress.md`.
- **The CA migration is finished: all 17 hosts are on Let's Encrypt and nothing consumes
  `linuxguru-ca`** (dormant, not deleted; `var.ca_certfile`/`ca_keyfile` remain a standing
  **plan-time** dependency of `stacks/core`). Checklist:
  `modules/cert_manager/README.md`.

## In flight — namespace ingress rollout, part 2

The "media treatment" for the remaining namespaces. `media` is the **only** namespace
with enforced NetworkPolicies (locked down 2026-09-12); everything else is open to any
cluster pod. Method (validated by hand, not yet in code): render staged policies via a
`staged` flag on `firewalls/policy` (+ pass-through on `limited_ingress`), stage → watch
a few days of real traffic (a login, an Argo sync, a fresh image pull) → flip
`staged = false`.

- Staging is **proven** (an allow-list staged on `argo` logged `pendingPolicies: Deny`
  while traffic kept flowing) but **the `staged` flag does not exist in code yet**
  (grep-verified 2026-09-14) — implementing it is the first concrete task.
- Guest lists were never written down (the `TODO.md` they pointed at does not exist);
  derive them from Goldmane/Whisker flow data, not guesses.
- Highest-value first candidates: `kube-auth`, `devops-harbor`, `argo`, `ai`,
  `monitoring`, `kube-certificates`, `blender`.
- `argo` also has **no egress fence** (`enable_egress_firewall=false`).

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

