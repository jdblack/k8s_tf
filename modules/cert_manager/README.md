# `cert_manager` — cert-manager, a private CA, and Let's Encrypt

Installed by `stacks/core`. Two ClusterIssuers, one per trust model:

| ClusterIssuer | Type | Serves | Trusted by |
|---|---|---|---|
| `linuxguru-ca` | `ca`, backed by a self-signed local CA | the hosts whose **in-cluster** consumers pin the CA by issuer name: `auth.vn` itself, `harbor`, `grafana`, `argo-wf` (OIDC apps that mount the CA bundle), plus `ollama.vn` (manifest owned by the external app-of-apps repo) — 5 of 17 certs on 2026-09-15 | clients that installed `~/.ssl/ca.crt` |
| `letsencrypt` | `acme`, **DNS-01 via Route53** (its only solver) | every other host: plex (public gateway), vaultwarden, `argo-cd`, `s3`/`master.seaweedfs`, `admin.seaweedfs`, `whisker`, and all five media apps — yes, `.vn` hosts (see "Signing a `.vn` host") — 12 of 17 certs on 2026-09-15 | public roots — no client setup |

## What it creates

| Resource | Detail |
|---|---|
| namespace `kube-certificates` | `var.namespace` default |
| Secret `linuxguru-ca` (`kubernetes.io/tls`) | `tls.crt` / `tls.key` read with `file()` from `var.ca_certfile` / `var.ca_keyfile`, whose **defaults are `~/.ssl/ca.crt` and `~/.ssl/ca.key`** — those files must exist on the machine running tofu |
| ConfigMap `linuxguru-ca`, deliberately **without a namespace** (so it lands in `default`) | the CA cert, kept cluster-wide for consumers `modules/harbor/core` (reads it from `default`) and `modules/monitoring/prometheus` (mirrors it into `monitoring` for Grafana's OIDC TLS) |
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
`stacks/core/devops.tf` (argo-cd), `stacks/core/storage.tf` (a `cert_issuers` map
keyed by visibility), `stacks/mantle/storage.tf` (seaweedfs admin) and
`stacks/mantle/observability.tf` (whisker).

Then `tofu -chdir=stacks/<stack> apply` — there is nothing else to do. The
gateway-shim names its Certificate after the Secret the listener references
(`cert-<fqdn>`), so an issuer change re-issues **in place**: same Secret, same
listener, no `certificateRefs` churn, and rollback is reverting the argument. A
whole batch is fine: **2026-09-15 flipped 9 hosts (3 core + 6 mantle) in one
pass**, and all 12 public certs were serving within ~4 minutes — issuance runs in
parallel, and the weekly limit is per *registered domain* (50), not per host.

Two things to know before flipping more than one host (the five hosts still on
the CA are exactly the ones the first bullet catches):

- **The CA trust material is named after the issuer.** `harbor`,
  `monitoring/prometheus` and `argo/mantle` fetch the CA ConfigMap with
  `data "kubernetes_config_map_v1" { name = var.cert_issuer }`, and Grafana /
  Argo Workflows mount it in ways that *replace* the container trust bundle
  (`SSL_CERT_FILE`, a `ca-certificates.crt` subPath mount). Retarget those at the
  CA by name (or drop them) before the whole `.vn` namespace moves, or the plan
  fails on a missing `letsencrypt` ConfigMap / a public cert nothing trusts.
- **Certificates are public.** Per-host certs publish the hostname in Certificate
  Transparency logs. A `*.vn.linuxguru.net` wildcard avoids that, but
  `listener_set` derives the Secret name from the hostname
  (`cert-*.vn.linuxguru.net` is not a legal object name) and one wildcard per
  namespace runs into Let's Encrypt's duplicate-certificate limit.

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
