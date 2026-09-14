# `cert_manager` — cert-manager, a private CA, and Let's Encrypt

Installed by `stacks/core`. Two ClusterIssuers, one per trust model:

| ClusterIssuer | Type | Serves | Trusted by |
|---|---|---|---|
| `linuxguru-ca` | `ca`, backed by a self-signed local CA | **no host since 2026-09-15** — the four consumers (`auth.vn`, `harbor`, `grafana`, `argo-wf`) moved to `letsencrypt` and their CA injections were deleted. The issuer is kept only because the module still creates it; read "If a private CA ever comes back" before reusing it | clients that installed `~/.ssl/ca.crt` |
| `letsencrypt` | `acme`, **DNS-01 via Route53** (its only solver) | **all 17 hosts since 2026-09-15**: `auth.vn`, `harbor`, `grafana`, `argo-wf`, `argo-cd`, `ollama.vn` (manifest owned by the external app-of-apps repo), plex (public gateway), vaultwarden, `s3`/`master.seaweedfs`, `admin.seaweedfs`, `whisker`, and all five media apps — yes, `.vn` hosts (see "Signing a `.vn` host") | public roots — no client setup |

## What it creates

| Resource | Detail |
|---|---|
| namespace `kube-certificates` | `var.namespace` default |
| Secret `linuxguru-ca` (`kubernetes.io/tls`) | `tls.crt` / `tls.key` read with `file()` from `var.ca_certfile` / `var.ca_keyfile`, whose **defaults are `~/.ssl/ca.crt` and `~/.ssl/ca.key`** — those files must exist on the machine running tofu |
| ConfigMap `linuxguru-ca`, deliberately **without a namespace** (so it lands in `default`) | the CA cert. **No consumer left as of 2026-09-15** — this was the single source every in-cluster injection copied from, so nothing ships a CA any more (see "If a private CA ever comes back") |
| Helm release `cert-manager` | pinned `v1.21.1`; `crds.enabled` + `crds.keep`, the **gateway-shim** (`enableGatewayAPI`) and the `ListenerSets` feature gate, so an annotated `ListenerSet` gets its `cert-<fqdn>` secret automatically; `--dns01-recursive-nameservers[-only]` pointed at public resolvers (see Traps) |
| ClusterIssuer `linuxguru-ca` | `ca`, pointing at the Secret above |
| ClusterIssuer `letsencrypt` | `acme`, `dns01/route53` with `hostedZoneID` pinned to `var.data["R53_ZONEID"]`; credentials out of `var.data` |
| Secret `certman-route53-letsencrypt` | the Route53 key the ACME DNS-01 solver reads |

No `Certificate` is ever written by hand: [`../network/gateway/expose`](../network/gateway/expose/README.md)
annotates the ListenerSet with the issuer and the shim renders the Certificate +
TLS secret in the app's own namespace.

## The local CA

The CA lives **outside** Terraform — this module only consumes its cert and key.
It is self-signed, `CN=vn.linuxguru.net`, and valid for one year:

```sh
# ~/.ssl/gencert — the invocation that made the current ca.crt
openssl req -x509 -new -nodes -key ca.key -sha256 -days 365 -out ca.crt \
  -config openssl.cnf \
  -subj "/C=VN/ST=Ho Chi Minh City/L=Ho Chi Minh City/O=Linuxguru/CN=vn.linuxguru.net/emailAddress=jblack@linuxguru.net"
```

`~/.ssl/openssl.cnf` carries the CA extensions (`basicConstraints=CA:TRUE`,
key usage, SANs) — without it the "CA" is just a leaf cert and nothing will
validate it. Rotating the CA re-issues every certificate signed by it, so keep
the previous `ca.crt` around until every client has been updated.

## Deliberately egress-only

`security.tf` installs `basic_internet` with `allow_to_k8sapi = true` and **no
ingress policy**. The kube-apiserver calls the cert-manager webhook from the
nodes — host traffic, not a pod namespace — so any ingress restriction here
breaks certificate issuance cluster-wide. The egress fence (same-namespace, DNS,
API, internet for Let's Encrypt + Route53) is the useful part anyway.

## Signing a `.vn` host with Let's Encrypt

Any host works, because Route53 is the public authority for the whole
`linuxguru.net` tree — including every `.vn.linuxguru.net` name. `vn.linuxguru.net`
is **not** delegated, `bind9` only serves the LAN view, and the zone holds **no
`.vn` records at all**: every `.vn` name publicly resolves to the WAN IP because
`*.linuxguru.net` is an **A alias to `home.linuxguru.net`**, and Route53 applies a
wildcard at *any* depth below the zone (verified three levels down, 2026-09-15).
No `.vn` wildcard, extra zone or NS delegation is needed — and deleting a `.vn`
record changes nothing publicly.

The DNS-01 TXT is an explicit record at `_acme-challenge.<host>.vn.linuxguru.net`,
created and deleted around each challenge. It coexists with that wildcard because
they are different RR types (verified: `A deep.deeper.vn…` answers from the
wildcard while the `TXT` at the challenge name is NODATA-until-created), so
validation sees the TXT and no inbound reachability is involved.

The issuer comes from whichever stack renders the ListenerSet. `modules/media`
signs **every** app with the public issuer (they are leaf-only — nothing
in-cluster validates them) and takes a per-app `cert_issuers` override for
exceptions:

```hcl
# stacks/mantle/media.tf -- optional per-app override (modules/media/variables.tf)
# to pin one app back to the CA without moving its namespace.
cert_issuers = {
  sonarr = var.deployment.cert_authorities.private
}
```

Everywhere else it is the module's `cert_issuer` argument, set in the stack:
`stacks/core/devops.tf` (argo-cd, harbor), `stacks/core/monitoring.tf` (grafana),
`stacks/core/auth.tf` (auth.vn), `stacks/mantle/devops.tf` (argo-wf),
`stacks/core/storage.tf` (a `cert_issuers` map keyed by visibility),
`stacks/mantle/storage.tf` (seaweedfs admin) and `stacks/mantle/observability.tf`
(whisker).

Then `tofu -chdir=stacks/<stack> apply` — there is nothing else to do. The
gateway-shim names its Certificate after the Secret the listener references
(`cert-<fqdn>`), so an issuer change re-issues **in place**: same Secret, same
listener, no `certificateRefs` churn, and rollback is reverting the argument. A
whole batch is fine: **2026-09-15 flipped 9 hosts (3 core + 6 mantle) in one
pass**, and all 12 public certs were serving within ~4 minutes — issuance runs in
parallel, and the weekly limit is per *registered domain* (50), not per host.

Two things to know before flipping more than one host:

- **A host with in-cluster CA consumers needs those injections deleted in the
  *same apply* as the flip.** Deleting them earlier breaks that app's SSO against
  a still-private issuer; deleting them later breaks it against an already-public
  one, because the injections that *replace* the bundle (`SSL_CERT_FILE`, a
  `ca-certificates.crt` subPath mount) know nothing about public roots. That is
  what gated the last four (`auth.vn`, `harbor`, `grafana`, `argo-wf`) — and why
  they could not simply be flipped one at a time while their listener and their CA
  lookup share one `cert_issuer` variable. Full list, semantics and file
  locations: "If a private CA ever comes back".
- **Certificates are public.** Per-host certs publish the hostname in Certificate
  Transparency logs. A `*.vn.linuxguru.net` wildcard avoids that, but
  `listener_set` derives the Secret name from the hostname
  (`cert-*.vn.linuxguru.net` is not a legal object name) and one wildcard per
  namespace runs into Let's Encrypt's duplicate-certificate limit.

## If a private CA ever comes back

Nothing here needs one today: every host is public, and the CA's only remaining
footprint is the ClusterIssuer plus the `kube-certificates/linuxguru-ca` Secret
and `default/linuxguru-ca` ConfigMap. If one is ever reintroduced, the trust has
to be injected **by hand** into each consumer — there is no cluster-wide switch,
and a container never reads the node's trust store.

**First question: does the knob *add to* or *replace* the container's bundle?**

| Consumer | Knob (where it lived) | Semantics | Removal timing |
|---|---|---|---|
| Harbor | `caBundleSecretName` → Secret with a `ca.crt` key (`modules/harbor/core/{main,locals,secrets}.tf`) | **adds** an extra bundle Harbor loads on top | any time |
| Argo CD (server) | `argocd-cm` → `oidc.config.rootCA` (`modules/argo/mantle/argo-cd/oauth2.tf`) | roots for the **OIDC issuer**; documented as *additional* roots, but augment-vs-replace was never verified on this cluster (see below) | any time |
| Argo CD (repo-server) | `argocd-tls-certs-cm`, mounted at `/app/config/tls` | **adds** a per-hostname trust store for chart pulls | any time |
| Grafana | `SSL_CERT_FILE` → mounted CA file (`modules/monitoring/prometheus/{locals,grafana}.tf`) | **REPLACES** the Go trust bundle | same apply as the flip |
| Argo Workflows | `ca-certificates.crt` **subPath mount** from a mirrored ConfigMap (`modules/argo/mantle/argo-workflows/{locals,oauth2}.tf`) | **REPLACES** the container bundle (chart 0.46.x has no `server.sso.rootCA`) | same apply as the flip |

"Same apply as the flip" is what makes this awkward: delete those injections
*earlier* and the app cannot validate a still-private issuer; delete them *later*
and it cannot validate an already-public one, because a bundle that was replaced
knows nothing about public roots. It is also why the last four hosts could not be
flipped one at a time — their listener and their CA lookup shared a single
`cert_issuer` variable.

### Argo CD — two independent trust stores, and only one is obvious

This is the painful one: the two are unrelated, they live on different pods, and
neither is visible in the Application YAML.

1. **OIDC trust** — `argocd-cm` → `oidc.config.rootCA`. Roots used when
   `argocd-server` talks to the authenticator (`auth.vn`). Two traps:
   - It is written with `kubernetes_config_map_v1_data`, a **merge** into the
     chart-owned `argocd-cm`. Removing the key from the HCL is not always enough
     — always confirm the live object:
     ```sh
     kubectl -n argo get cm argocd-cm -o json | jq -r '.data["oidc.config"]' | grep -i rootca
     ```
     A stale value is a landmine: harmless while the CA validates, then a broken
     OIDC handshake (`x509: cannot validate certificate`) the day it expires.
   - `argocd-server` parses the OIDC config **once, at startup**. Restart it
     (`kubectl -n argo rollout restart deploy/argo-cd-argocd-server`) or you are
     testing the previous config.
   - *Unverified:* whether `rootCA` augments the system pool or replaces it. Test
     before relying on it — if OIDC works against the private issuer **and**
     against a public one, it augments; if it breaks the moment the issuer goes
     public, it replaced the pool. This repo removed `rootCA` in the same apply as
     the flip, so it never depended on the answer.

2. **Registry trust** — `argocd-tls-certs-cm`, mounted at `/app/config/tls` on the
   **repo-server** pod (`argo-cd-argocd-repo-server`). Keys are hostnames, values
   are PEM. This is what lets `repo-server` pull a chart from a privately-signed
   registry (`harbor.vn.linuxguru.net/linuxguru`). It is **not** covered by
   `rootCA` above, and **not** fixed by restarting `argocd-server` — different
   pod, different trust store.

   **This omission was a real, silent breakage here.** The Helm repo was
   registered with verification on (`insecure` unset) while `argocd-tls-certs-cm`
   was empty, so every chart pull failed and the two Applications using it
   (`corsless`, `llm-embedder`) sat `Unknown` for months with no alert:
   ```
   rpc error: ... unable to get tags: failed to get tags:
   Get "https://harbor.vn.linuxguru.net/v2/linuxguru/corsless-helm/tags/list":
   tls: failed to verify certificate: x509: certificate signed by unknown authority
   ```
   Moving the registry to a public issuer fixed it for free, because the
   repo-server image already ships the public roots. If a private registry comes
   back, this ConfigMap is the fix:
   ```sh
   kubectl -n argo get applications -o json \
     | jq -r '.items[].status.conditions[]?.message' | grep -i x509   # the symptom
   kubectl -n argo get cm argocd-tls-certs-cm -o jsonpath='{.data}'   # the fix site
   ```

### Harbor

`caBundleSecretName` takes a **Secret whose key is `ca.crt`**, not a ConfigMap —
which is why `modules/harbor/core` read the CA ConfigMap from `default` and
re-wrapped it. Harbor needed it to validate the OIDC issuer
(`oidc_verify_cert = true`).

**Harbor's OIDC config is not in this repo**: it lives in Harbor's database
(`harbor_config_auth`), so neither `grep` nor `kubectl get -o yaml` reveals it.
That is the invisible consumer to remember — the failure mode is a broken login,
not a broken registry.

### Grafana and Argo Workflows

Both mirrored the CA into the app's own namespace first, because a ConfigMap
volume can only mount from the pod's own namespace while the CA ConfigMap lived
in `default`. Grafana then pointed `SSL_CERT_FILE` at the file. Workflows mounted
it *over* `/etc/ssl/certs/ca-certificates.crt` with `subPath: tls.crt` — and a
subPath mount is snapshotted at pod start, so a rotated CA needs a rollout too,
not just a ConfigMap update. On chart >= 1.x / app >= v4 use Workflows'
`server.sso.rootCA` instead, which augments the trust store rather than replacing
it.

### Prove nothing is left

One sweep beats reading every module — every ConfigMap and Secret in the cluster
whose contents hold the CA (the fragment is any chunk of the CA's base64 body,
e.g. the first 40 characters after `BEGIN CERTIFICATE`):

```sh
CAF='MIIGETCCA/mgAwIBAgIUSqMuDS9B7KQXzQvXUGQ0j7YpDSc'
kubectl get cm -A -o json | jq -r --arg f "$CAF" \
  '.items[] | (.data // {}) as $d | select([$d[]] | any(contains($f))) | "cm " + .metadata.namespace + "/" + .metadata.name'
kubectl get secret -A -o json | jq -r --arg f "$CAF" \
  '.items[] | (.data // {}) as $d | select([$d[] | @base64d] | any(contains($f))) | "secret " + .metadata.namespace + "/" + .metadata.name'
```

Mind the `@base64d` on the Secret half: Secret values are base64, so a literal
substring match finds nothing and looks like a clean sweep. After the 2026-09-15
migration the only hits are the CA itself — `default/linuxguru-ca` and
`kube-certificates/linuxguru-ca`.

Two more places a CA lingers outside the cluster: the **nodes**
(`/usr/local/share/ca-certificates/` + `update-ca-certificates`, applied by
`initial_setup.yml` in the k8s repo) and **`~/.ssl/ca.crt` on the operator box**,
which `var.ca_certfile` reads at plan time.

## Traps

- **`file()` runs at plan time.** A renamed/missing `~/.ssl/ca.*` fails the plan;
  there is no fallback and no default cert.
- **DNS-01 needs no inbound reachability.** Validation is a `_acme-challenge`
  TXT record, so a host served only by the private gateway can still hold a
  publicly-trusted cert (vaultwarden, sonarr).
- **Split-horizon DNS is why two settings in this module are load-bearing.** The
  cluster resolves through the LAN resolver, which is authoritative for
  `vn.linuxguru.net` (bind9) and has never seen the challenge TXT — that record
  lives in the Route53 `linuxguru.net` zone. Hence `hostedZoneID` on the solver
  (without it, zone discovery climbs SOA records to `vn.linuxguru.net`, a zone
  with no Route53 counterpart, and the challenge dies with
  `zone vn.linuxguru.net not found in Route 53`) and `--dns01-recursive-nameservers`
  + `--dns01-recursive-nameservers-only` in `locals.tf` (without them the
  self-check looks up the authoritative NS through bind9 and asks *it* for a TXT
  that only Route53 has).
- **`Waiting for DNS-01 challenge propagation` for a minute is normal.** The
  solver writes the TXT with a 10s TTL and cert-manager polls the public view;
  the challenge reaches `valid` on its own (verified 2026-09-15, ~90s; the
  9-host batch took ~4 min end to end, and a challenge object staying `pending`
  ~3 min while others finish is just the self-check waiting).
- **Rate limits are per registered domain, and nowhere near current use.** 50 new
  certs per registered domain per week, 5 *duplicate* certs per week, 5 failed
  validations per hostname per hour; renewals (at 2/3 of lifetime) are exempt from
  the 50. The 2026-09-15 batch of 9 was ~¼ of the weekly cap, so batching is
  cheap — but a broken solver burns the 5-failures-per-hour budget fast, and
  there is **no staging ClusterIssuer** in this module (`server` is hardcoded to
  the production directory). Iterating on solver config means temporarily
  pointing that `server` at `.../staging/directory`, and staging certs are not
  trusted — so don't leave it applied.
- **A failed renewal is invisible today.** cert-manager serves `certmanager_*`
  on `:9402` of its own Service, but nothing in the repo creates a
  `ServiceMonitor` or an expiry `PrometheusRule`, so a silent solver failure
  surfaces as an expired cert on day 90 — not as an alert. Renewal is at 2/3 of
  lifetime, so there is ~30 days of slack to notice by hand.
- **`*.linuxguru.net` is an A alias, and that is load-bearing in both
  directions.** Every `.vn` name resolves publicly because of it (see above), so
  you cannot make `.vn` names NXDOMAIN by deleting `.vn` records — the only lever
  is that wildcard. And do **not** convert it to a CNAME: a wildcard CNAME answers
  `cnameStrategy: Follow` queries for `_acme-challenge.<host>` (cert-manager's
  docs warn about exactly this), whereas an A alias leaves TXT queries as plain
  NODATA. The issuer here keeps the default `cnameStrategy: None`.
- **`zoneid` was never an API field.** The real field is `hostedZoneID`;
  `external_cert.tf` used to pass `zoneid`, which the server pruned, so nothing
  was ever pinned. Pinning is also what keeps the least-privilege key honest: it
  can only touch `Z3FM4Y4P2572E4`.
- **The Route53 key is least-privilege and needs `route53:GetHostedZone`** if
  anything else is going to manage records with it — see
  [`../network/dns/route53_record/README.md`](../network/dns/route53_record/README.md), Trap 1.
