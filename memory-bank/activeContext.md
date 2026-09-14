# Active Context

## Current state (as of 2026-09-15)

- Branch `main`, HEAD `5f0f582 docs: add Cline memory bank system`. The
  `cert_manager` / `media` / README changes from this session are **uncommitted**.
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
  untargeted `tofu plan` in **both** stacks. 12 of 17 certs are LE; the 5 left on
  the CA are exactly the ones an in-cluster consumer pins by issuer name —
  `auth.vn`, `harbor`, `grafana`, `argo-wf`, `ollama`.
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
    ConfigMap name. Needs a `ca_name` input split first, or the plan dies on a
    missing `letsencrypt` ConfigMap.
  - **Group 3 — `auth.vn` last.** Argo CD `rootCA` and Harbor
    `caBundleSecretName` only *augment* trust (safe), but Grafana's
    `SSL_CERT_FILE` and Argo Workflows' `ca-certificates.crt` subPath mount
    **replace** the container bundle — delete both overrides when `auth.vn` goes
    public, or Grafana/Workflows stop trusting every public root.
  - **`ollama.vn` is not ours to flip**: its ListenerSet comes from the external
    app-of-apps repo (`stacks/apps`).
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
- **Grafana's CA trust *replaces* the bundle** — confirmed live: the module
  renders the CA into a `grafana-ca` ConfigMap mounted at `/etc/grafana/certs`,
  with `SSL_CERT_FILE=/etc/grafana/certs/tls.crt`. Grafana therefore trusts *only*
  the private CA today; when `auth.vn` goes public that env var and mount must go
  too or Grafana can't verify any public endpoint.
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
