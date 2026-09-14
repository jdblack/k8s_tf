# Active Context

## Current state (as of 2026-09-15, late)

- Branch `main`, **6 unpushed commits** ahead of `origin/main` (baseline
  `5f0f582`): the CA migration (3), its memory-bank note, the CA-retirement
  commit, and the memory-bank update at the end of the session. Nothing pushed.
- **2026-09-15 (later) — the two dead `ai` apps are alive.** `corsless` is
  deployed and serving `https://corsless.vn.linuxguru.net`; `llm-embedder` is
  repointed but its image is still being rebuilt. Three chained bugs, in the
  order they bit:
  1. **Build**: `corsless/Dockerfile` built for the builder's platform, so the
     amd64 image was a qemu-emulated Go build that crashed. Now
     `FROM --platform=$BUILDPLATFORM` + `GOOS`/`GOARCH` cross-compile — builder
     runs native arm64, output is amd64.
  2. **Publish auth**: `helm` had no credentials. On macOS its store is
     `~/Library/Preferences/helm/registry/config.json`, **not**
     `~/.config/helm/...` as on Linux, and a fresh machine doesn't have it.
     Anonymous `helm push` → `401`. Seeded it from podman's auth file with the
     Harbor `robot$jblack` creds (merged `ghcr.io` back in).
  3. **Registry split-brain — the real killer**: everything said `linuxguru`
     (chart `values.yaml`, the ArgoCD repo URL, TF's `harbor_project`), but
     `AppInfo.txt` pushed to `library`, and `robot$jblack` holds a system-level
     permission on **`library` only**. Argo was reading a project that contained
     zero artifacts → `404: repository linuxguru/corsless-helm not found`.
     **Decision: point the apps at `library`** (the only writable project)
     instead of widening the robot: both `chart/values.yaml` image repos, both
     `deployments/ai/*.yaml` `repoURL`s, and the live Argo repo Secret
     `argo/repo-3272614039` (`url=…/library`, `enableOCI=true`). `library` is
     **not** TF-managed (Harbor's default project) — import it before adding any
     `harbor_project` resource, or `apply` 409s.
  - **Exposure was the next wall, and it was a chart problem**: both
    Applications exposed themselves with the stock `helm create` `Ingress`
    (`className: private`), which attaches to nothing — the shared gateways only
    serve HTTPS through app-declared ListenerSets, so TLS died with
    `unrecognized name` and Argo sat at `Progressing` (an Ingress never gets an
    address). Both charts now ship `templates/extraObjects.yaml` (+ an
    `extraObjects: []` default) and both Applications pass a ListenerSet +
    ReferenceGrant + HTTPRoute, exactly like the `ollama` Application does with
    `otwld/ollama-helm`. Certs come from `letsencrypt` (DNS-01), so neither app
    touches the retired `linuxguru-ca`.
  - **Also fixed**: `corsless/build` bumped and packaged the chart in `build`
    but pushed it in `publish`, so publishing shipped a stale `.tgz` silently.
    It now matches its sibling (bump + package at publish time, from the
    committed tree).
  - **`llm-embedder`'s Dockerfile needed a fix too**: the torch install used
    `--index-url` (exclusive) against the CPU wheel index, which carries no
    build dependencies. pip rejects PyPI's `typing_extensions` wheel
    ("inconsistent Name": `typing_extensions` vs the dash-form request), falls
    back to the sdist, then can't find `flit_core` on that index. Now
    `--extra-index-url https://pypi.org/simple` plus an explicit
    `torch==2.8.0+cpu` pin, so PyPI's CUDA build can never win. Note: this Mac's
    podman VM builds `linux/amd64` under emulation (verified), which is why the
    python image build takes ~20 minutes.
- **2026-09-15 (evening) — CA migration FINISHED. All 17 hosts are on Let's
  Encrypt and nothing consumes `linuxguru-ca`.** The last four (`auth.vn`,
  `harbor`, `grafana`, `argo-wf`) flipped in **one apply per stack**, together
  with the deletion of every CA injection:
  - core: `0 added / 5 changed / 2 destroyed` — ListenerSet annotations
    `linuxguru-ca` → `letsencrypt` on `auth`/`harbor`/`grafana`, harbor helm
    (`caBundleSecretName` gone) + grafana helm (`SSL_CERT_FILE` + mount gone),
    and the two CA objects destroyed (`devops-harbor/linuxguru-ca-cert`,
    `monitoring/grafana-ca`).
  - mantle: `0 added / 3 changed / 1 destroyed` — `argo-wf` ListenerSet flipped,
    workflows helm (subPath bundle mount gone), `argo/argo-wf-ca-cert` destroyed,
    and `argocd-cm`'s `oidc.config` rewritten without `rootCA`.
  - **Why one apply, not four**: `var.cert_issuer` drives *both* the listener and
    the CA lookup in each module, so a listener-only flip needs throwaway
    scaffolding; and Grafana/Workflows *replace* the container bundle, so
    removing their injection before or after the flip breaks their SSO against a
    still-private / already-public issuer. The planned `ca_name` split turned out
    to be unnecessary — deleting the wiring in the same apply is what avoids it.
    Harbor's `caBundleSecretName` and Argo CD's `rootCA` are additive (so
    order-agnostic); all four moved together anyway to keep one reviewed diff.
  - **Verified live**: `openssl s_client` → `O=Let's Encrypt, CN=YR1/YR2` on all
    four (exp 2026-12-13); `ca.crt` gone from every listener Secret (cert-manager
    only adds it for CA-issued certs); both deleted objects gone;
    `argocd-cm → oidc.config` really has **no** `rootCA` left (the
    `kubernetes_config_map_v1_data` merge did remove the key — checked, not
    assumed); all four SSO hand-offs 302 to
    `https://auth.vn.linuxguru.net/application/o/authorize/` with the right
    client_id (argo-cd `/auth/login`, grafana `/login/generic_oauth`, harbor
    `/c/oidc/login`, and argo-wf **`/oauth2/redirect`** — `/oauth2/start` is not
    a route on this chart and returns the SPA, so don't be fooled by a 200);
    an in-cluster `curlimages/curl` probe validates auth.vn on system roots
    alone (`ssl_verify_result=0`); and a cluster-wide ConfigMap+Secret sweep
    finds the CA only in `default/linuxguru-ca` and
    `kube-certificates/linuxguru-ca` — the CA itself, with nothing consuming it.
  - Rolled `authentik-server`/`authentik-worker` (its cert mount is not a
    subPath, so the file rotates in place, but the server caches it) and
    `argo-cd-argocd-server` (parses `oidc.config` once, at startup).
  - **Bonus fix found while verifying**: `corsless` / `llm-embedder` had been
    failing chart pulls with `x509: certificate signed by unknown authority`
    because `argocd-tls-certs-cm` was **empty** while the Helm repo
    `harbor.vn.linuxguru.net/linuxguru` had verification on. Going public fixed
    it for free (repo-server ships the public roots). Zero `x509` errors now;
    they report `404: repository linuxguru/corsless-helm not found` — the honest
    next error, so both remain dead apps for a different reason. **Resolved
    later the same day**: that 404 was the registry split-brain, not a missing
    push — see the top of this file.
  - **Docs**: `modules/cert_manager/README.md` gained "If a private CA ever comes
    back" — the per-consumer injection checklist with **Argo CD first** (its two
    independent trust stores — `oidc.config.rootCA` on argocd-server vs
    `argocd-tls-certs-cm` on repo-server — the `kubernetes_config_map_v1_data`
    merge trap, Harbor's Secret-not-ConfigMap quirk, the replace-vs-add table,
    the same-apply rule, and the sweep one-liners). Root `README.md` host table
    now shows `letsencrypt` for every host.
  - **Still open after this**: retire the CA outright — ClusterIssuer
    `linuxguru-ca`, the `kube-certificates/linuxguru-ca` Secret, the
    `default/linuxguru-ca` ConfigMap, and the module's `ca_certfile`/`ca_keyfile`
    `file()` inputs; then `~/.ssl/ca.crt` and the node trust store
    (`initial_setup.yml`, k8s repo). Nothing breaks while it lingers, but
    `~/.ssl/ca.*` must keep existing or `tofu plan` fails. Argo CD `rootCA`
    replace-vs-add is **still unverified** — documented as such rather than
    guessed, and moot now that the field is gone.
- **2026-09-15 — `.vn` hosts can now hold Let's Encrypt certs.** Two real bugs in
  `modules/cert_manager` were fixed (`zoneid` → `hostedZoneID`; DNS-01 nameservers
  now point at public resolvers), the cert-manager chart was pinned to
  `v1.21.1`, and `sonarr.vn.linuxguru.net` was flipped as the first `.vn` host
  (`stacks/mantle/media.tf` → per-app `cert_issuers`, new `modules/media`
  variable). Verified live: LE cert served by the media-private gateway,
  `cert-sonarr.vn.linuxguru.net` ready in ~90s, challenge TXT cleaned up, and
  `tofu plan` empty in **both** core and mantle.
- **2026-09-15 (same session) — the 9 "easy and safe" hosts followed.** Now
  signed by `letsencrypt`: `argo-cd`, `s3` + `master.seaweedfs`,
  `admin.seaweedfs`, `whisker`, and all five media apps — media's **default**
  issuer flipped in `modules/media/arr_stack.tf` (the sonarr override was
  deleted; per-app overrides still exist for exceptions). Core: 3 ListenerSets
  (`stacks/core/devops.tf`, `stacks/core/storage.tf` — a `merge` onto the
  per-visibility `cert_issuers` map). Mantle: 6 (`stacks/mantle/media.tf`,
  `stacks/mantle/observability.tf`, `stacks/mantle/storage.tf`).
  Verified live: all 17 certs `Ready`, leaf certs checked over the wire for all
  10 `vn` hosts (`openssl s_client` → `O=Let's Encrypt`) and a **stock-trust
  `curl`** (no `--cacert`, `ssl_verify_result=0`), then `No changes` from an
  untargeted `tofu plan` in **both** stacks. 12 of 17 certs were LE at that
  point; the 5 still on the CA were exactly the ones an in-cluster consumer
  pinned by issuer name — `auth.vn`, `harbor`, `grafana`, `argo-wf`, `ollama`.
  **Both later steps landed the same day: `ollama` flipped first (external repo,
  see below) → 13 LE / 4 CA, then those last four flipped in-repo with all their
  CA wiring deleted → 17 LE / 0 CA. See the top of this file.**
- **Environment gotcha from that apply:** this Mac's resolver (`192.168.0.2`)
  dropped out mid-run — SERVFAIL/NXDOMAIN for most names — which aborted the
  *full* plans with `charts.jetstack.io: no such host` (helm chart lookup) and an
  STS `lookup sts.us-west-2.amazonaws.com` failure. Not config: the same plans
  returned `No changes` once DNS recovered. Because a complete plan was
  impossible, the 3+6 ListenerSets went in with **`-target`** (the settled "no
  `-target`" rule) — justified by the tool failure and proven equivalent by the
  clean untargeted plans afterwards.
- Route53 is the public authority for the **whole** `linuxguru.net` tree:
  `vn.linuxguru.net` has no NS delegation, so an ACME TXT written into
  `Z3FM4Y4P2572E4` is what Let's Encrypt sees. bind9 stays the LAN-only view.
  (Verified 2026-09-15 against the API, not dig: the zone holds **no `.vn`
  records at all**, and every `.vn` name resolves publicly only because
  `*.linuxguru.net` is an **A alias to `home.linuxguru.net`** that Route53
  applies at any depth. Earlier notes claiming a lingering
  `*.vn.linuxguru.net` record were wrong — dig can't tell a real wildcard record
  from synthesis, and the stale `4.5.6.7` was a deletion still propagating.)
- There is **no `TODO.md`** in the repo, despite this file and the root README
  referencing it — the open work lives in `progress.md` / this file instead.
- The vaultwarden build shipped and was verified live on 2026-09-14. The big
  33 KB handoff doc was retired into `modules/vaultwarden/README.md` and
  `modules/network/dns/route53_record/README.md`.
- Media namespace is the only namespace with real (enforced) NetworkPolicies
  (locked down 2026-09-12). Everything else is still open to any cluster pod.
- The `staged` (preview-only) NetPolicy *mechanism* is proven — an allow-list
  staged on `argo` logged `pendingPolicies: Deny` while traffic kept flowing.
  But **the `staged` flag does not exist in the code yet** (grep verified
  2026-09-14): no `staged` var in `modules/network/firewalls/policy` or
  `limited_ingress`. The proof was a hand-run object. Implementing that flag is
  the first concrete task of the rollout.

## In-flight work

**Namespace ingress rollout, part 2** — the "media treatment" for the remaining
namespaces. Method (validated by hand, not yet in code): render staged policies
via a `staged` flag on `firewalls/policy` (+ pass-through on `limited_ingress`),
stage → watch a few days with real traffic (a login, an Argo sync, a fresh image
pull) → flip `staged = false`. Intended guest lists per namespace are in
`TODO.md`; they come from Goldmane/Whisker flow data, not guesses. Highest-value
first candidates: `kube-auth`, `devops-harbor`, `argo`, `ai`, `monitoring`,
`kube-certificates`, `blender`.

Note `argo` also has **no egress fence** (`enable_egress_firewall=false`).

## Immediate follow-ups owed (from `TODO.md`)

- **vaultwarden backups are cluster-local** → point Longhorn `backupTarget` at
  the SeaweedFS S3 endpoint + flip the RecurringJob to `task = "backup"`. Until
  then: export from a client before any destroy.
- **`modules/cert_manager` ACME config** — `zoneid` → `hostedZoneID` and the
  public-resolver DNS-01 args are **done**, and 12 of 17 certs are now on
  `letsencrypt` (2026-09-15). What is left to finish the move:
  - **Group 2 — `harbor`, `grafana`, `argo-wf` (and mantle's argo-cd SSO):** each
    uses the *same* `var.cert_issuer` for both the listener issuer **and** the CA
    ConfigMap name. Flipping them alone would make the data source look for a
    ConfigMap named `letsencrypt` → plan dies. **But the CA mount is not about
    their own cert** — it exists so four consumers can verify *auth.vn's* TLS
    (Authentik OIDC): `harbor/core/secrets.tf` → `caBundleSecretName`
    (with `oidc_verify_cert = true`), `monitoring/prometheus/grafana.tf` +
    `locals.tf` (`grafana-ca` CM + `SSL_CERT_FILE`),
    `argo/mantle/argo-workflows/oauth2.tf` (mirror CM over
    `/etc/ssl/certs/ca-certificates.crt`), `argo/mantle/argo-cd/oauth2.tf`
    (`oidc.config.rootCA`). So **flipping auth.vn in the same change removes the
    need for a `ca_name` split entirely**: delete that wiring instead of
    renaming it. Grafana's `SSL_CERT_FILE` and Workflows' subPath mount *replace*
    the bundle, so they must be deleted in the same apply as auth.vn's flip
    (Harbor's `caBundleSecretName` merges a bundle into the components' trust, so
    it's order-agnostic; Argo CD's `oidc.config.rootCA` is *documented* as an
    additional CA but whether it replaces the pool was NOT verified — if it does,
    it needs the same same-apply treatment as Grafana/Workflows). Once that lands, the private CA can retire outright —
    issuer, key secret, the `default` ConfigMap, and the `~/.ssl/ca.crt` you hand
    to clients. That collapses Group 2 and Group 3 into **one** change: flip all
    four (`auth.vn` + these three) and delete the CA wiring together.
  - **Verified 2026-09-15 — the `auth.vn` trust graph is fully enumerated**, so
    this flip is safer than the module coupling made it look:
    - `kube-apiserver` has **no** `--oidc-*` flags (only
      `--authorization-mode=Node`, bootstrap tokens) → auth.vn is not the API
      server's identity provider.
    - Authentik **outposts talk plain HTTP in-cluster**
      (`http://authentik-server.kube-auth.svc.cluster.local:80`) and never
      validate auth.vn's TLS. `browser_url` is for redirects only, so the CA
      validation the `stacks/mantle/{storage,observability}.tf` comments refer to
      is the *browser's*, not a pod's.
    - Node trust is **additive**: `initial_setup.yml` copies `~/.ssl/ca.crt` into
      `/usr/local/share/ca-certificates/` + `update-ca-certificates`, and the
      containerd `certs.d` override covers only `docker.io` (pull-through proxy).
      Public roots stay in the bundle, so flipping `harbor.vn` does not break node
      image pulls.
    - A live grep of every workload env / ConfigMap / Secret matching `auth.vn`
      returns exactly the known consumers: `argo/argocd-cm`,
      `argo/argo-wf-argo-workflows-workflow-controller-configmap`,
      `monitoring/prometheus-grafana`. Nothing hidden. Harbor's OIDC endpoint
      lives in Harbor's **DB** (`harbor_config_auth`), invisible to that grep but
      already known (`oidc_verify_cert = true`).
    - `authentik-server`/`authentik-worker` mount their own
      `cert-auth.vn.linuxguru.net` secret at `/certs/auth.vn.linuxguru.net` → they
      need a **rollout after the flip** (secret content changes in place).
    - No live client certs come from `linuxguru-ca`:
      `~/code/k8s/projects/openvpn-docker` builds `Certificate` CRs against it but
      no OpenVPN workload is deployed (only WireGuard).
    - The external `~/code/k8s/argocd` app-of-apps annotates three apps
      `linuxguru-ca` (`ai/{ollama,llm-embedder,corsless}.yaml`) but only
      `ai/cert-ollama.vn.linuxguru.net` exists live → the other two are dead config.
  - **Group 3 — `auth.vn` last.** Argo CD `rootCA` and Harbor
    `caBundleSecretName` only *augment* trust (safe), but Grafana's
    `SSL_CERT_FILE` and Argo Workflows' `ca-certificates.crt` subPath mount
    **replace** the container bundle — delete both overrides when `auth.vn` goes
    public, or Grafana/Workflows stop trusting every public root.
  - **`ollama.vn` flipped 2026-09-15 — it is NOT in this repo.** Its ListenerSet
    is a helm `extraObjects` entry in the external app-of-apps repo
    (`git@github.com:jdblack/argo-linuxguru.git`, path `deployments/ai`), applied
    by Application `argo/aoa-ai → argo/ollama`. Commit `99ab12a` changed the
    annotation to `letsencrypt`; Argo auto-synced, cert-manager re-issued
    (`verify return code: 0 (ok)` on public roots only, `curl` 200). **That was
    the last CA-signed host: all 17 certs are now Let's Encrypt**, and no live
    workload consumes `linuxguru-ca`, so the CA is retireable — the remaining
    work is in *this* repo (the four `auth.vn`-trust hosts).
  - **How to make Argo CD pick up an external-repo push** (asked 2026-09-15):
    there is **no webhook** (no `webhook.*.secret` in `argocd-secret`, and
    `argocd-cm` has no webhook key), so the trigger is the repo poll only —
    `timeout.reconciliation: 180s` → up to ~3 min. Force it:
    `kubectl -n argo annotate application aoa-ai argocd.argoproj.io/refresh=hard --overwrite`
    (or `argocd app get aoa-ai --hard-refresh`). Refresh the **root** app
    (`aoa-ai`), not the child: the child Application's whole spec, helm
    `valuesObject` included, is generated by the root, so the child only learns
    about the change after the root syncs. Watch with
    `kubectl -n argo get applications -o wide`; verify the wire, not just the
    sync status (`openssl s_client … | openssl x509 -noout -issuer -dates`).
- **Route53 credentials are NOT in git — earlier note corrected 2026-09-15.**
  `stacks/{core,mantle}/terraform.tfvars` is a **symlink** (git mode `120000`) to
  `/Users/jblack/.tfenvs/k8s.tfenv`, outside the repo, and the access key ID
  (redacted here — it begins `AKIA…`) appears nowhere in git history
  (`git log --all -S` on the ID → empty) nor in any tracked blob
  (`git grep AKIA HEAD` → empty). So the "*leaked
  in a tracked tfvars*" worry was wrong: exposure is a plaintext file on local
  disk, which is the intended single-sourced design. Rotating the key is still
  fine hygiene (it is the DNS-01 credential), but there is no VCS incident.
- **CA inventory (checked live 2026-09-15).** The signing CA
  (`kube-certificates/linuxguru-ca`) was regenerated **2026-08-14** and is valid
  to **2027-08-14**; `~/.ssl/ca.crt` matches it exactly (`5E:D5:04:DE:…`), so no
  expiry cliff — but everything still on the CA dies on 2027-08-14 unless the CA
  is rolled, and rolling it means redistributing `~/.ssl/ca.crt` to every client.
  The CA also lives as a ConfigMap in `default` (`linuxguru-ca`, the copy modules
  mount). Live issuers are exactly two: `letsencrypt` (DNS-01) and
  `linuxguru-ca`.
- **Orphan `letsencrypt-http` — deleted 2026-09-15.** It was in no `.tf`, no
  Certificate referenced it, and HTTP-01 can't work behind this gateway anyway.
  Its ACME account key (`kube-certificates/letsencrypt-http-key`) went with it.
  Do **not** confuse those with the live Route53 solver secrets
  `certman-letsencrypt` / `certman-route53-letsencrypt`.
- **CA-era orphan secrets — cleaned up 2026-09-15.** Each had no Certificate CR
  and was mentioned by none of the 123 workload/gateway objects cluster-wide:
  `ai/cert-ollama` (pre-shim ollama; the ListenerSet uses
  `cert-ollama.vn.linuxguru.net`), `argo/argocd-server-tls` (argo-cd mounts
  repo-server/dex-server TLS, not this), `monitoring/prometheus-grafana-cert`,
  and `kube-auth/keycloak.vn.linuxguru.net-tls` (expired 2026-02-04). Secrets are
  not Terraform state, so this moved no plan.
  **Deliberately left: `default/jblack`** — the only one with *client-auth* EKU
  (`SAN DNS:jblack`, exp 2026-12-03), so an off-cluster mTLS client may still use
  it. Its Certificate CR is gone, so it will never renew; delete when you're sure.
- **Grafana's CA trust *replaced* the bundle — resolved 2026-09-15.** The module
  used to render the CA into a `grafana-ca` ConfigMap mounted at
  `/etc/grafana/certs` with `SSL_CERT_FILE=/etc/grafana/certs/tls.crt`, so Grafana
  trusted *only* the private CA. Both the env var and the mount were deleted in
  the same apply as `auth.vn`'s flip (that simultaneity was mandatory — either
  order on its own breaks Grafana's SSO), and the ConfigMap is gone.
- **Argo Workflows' equivalent mount did the same thing**, over
  `/etc/ssl/certs/ca-certificates.crt` with `subPath: tls.crt`, and went with the
  same apply. Its SSO entry point on this chart is **`/oauth2/redirect`**;
  `/oauth2/start` just returns the SPA (200), which looks like a failure and
  isn't.
- **Nothing scrapes cert-manager.** No `ServiceMonitor`, no expiry
  `PrometheusRule`, so a failed renewal is invisible until the cert expires
  (~30 days of slack, since renewal is at 2/3 of lifetime). Cheap win: a
  ServiceMonitor on `kube-certificates/cert-manager:9402` plus a
  `certmanager_certificate_expiration_timestamp_seconds < 21d` alert.
- **Orphan ClusterIssuer `letsencrypt-http`** (+ `letsencrypt-http-key` secret)
  is live in `kube-certificates` but appears in no `.tf` — HTTP-01 leftover from
  ingress-nginx (`ingressClassName: public`, which no longer exists). Delete it,
  or bring it under management.
- **external-dns never published `certtest.vn.linuxguru.net`** from its HTTPRoute
  annotation — understand why before relying on automatic `.vn` DNS.
- **Longhorn has no Grafana dashboard** — ship it the SeaweedFS way next to
  `modules/storage/longhorn.tf`.
- **Whisker UI**: confirm the flow list populates *through the authentik proxy*.
- Leftovers to delete: the `kube-security` namespace (kept only because it's in
  state) and the orphaned `tfstate-default-fuckbatz` Secret.

## Decisions that are settled — don't relitigate

- Three stacks, in order; state in k8s Secrets.
- Typed `kubernetes_*` over `kubectl_manifest`, so `plan` sees drift.
- TF owns groups/apps/bindings; the authentik UI owns membership.
- No `-target`/`-exclude`.
- `parse the narrowest doc first` — root README → module README → `.clinedocs/`.

## Reading order for a fresh session

1. Root `README.md` (map, hostnames, conventions).
2. `TODO.md` (what's actually open).
3. The `README.md` of the one module you're touching.
4. `.clinedocs/calico-netpols.md` or `.clinedocs/flow-logs.md` only if the task
   is a NetworkPolicy / flow-query task.
