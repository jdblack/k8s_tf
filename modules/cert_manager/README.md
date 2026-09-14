# `cert_manager` — cert-manager, a private CA, and Let's Encrypt

Installed by `stacks/core`. Two ClusterIssuers, one per trust model:

| ClusterIssuer | Type | Serves | Trusted by |
|---|---|---|---|
| `linuxguru-ca` | `ca`, backed by a self-signed local CA | every `*.vn.linuxguru.net` host, on the private gateway *and* on each app's own gateway | clients that installed `~/.ssl/ca.crt` |
| `letsencrypt` | `acme`, **DNS-01 via Route53** (its only solver) | public-gateway apps, plus the one private-gateway host that wants a publicly-trusted cert (vaultwarden) | public roots — no client setup |

## What it creates

| Resource | Detail |
|---|---|
| namespace `kube-certificates` | `var.namespace` default |
| Secret `linuxguru-ca` (`kubernetes.io/tls`) | `tls.crt` / `tls.key` read with `file()` from `var.ca_certfile` / `var.ca_keyfile`, whose **defaults are `~/.ssl/ca.crt` and `~/.ssl/ca.key`** — those files must exist on the machine running tofu |
| ConfigMap `linuxguru-ca`, deliberately **without a namespace** (so it lands in `default`) | the CA cert, kept cluster-wide for consumers `modules/harbor/core` (reads it from `default`) and `modules/monitoring/prometheus` (mirrors it into `monitoring` for Grafana's OIDC TLS) |
| Helm release `cert-manager` | `crds.enabled` + `crds.keep`, the **gateway-shim** (`enableGatewayAPI`) and the `ListenerSets` feature gate, so an annotated `ListenerSet` gets its `cert-<fqdn>` secret automatically |
| ClusterIssuer `linuxguru-ca` | `ca`, pointing at the Secret above |
| ClusterIssuer `letsencrypt` | `acme`, `dns01/route53`, zone and credentials out of `var.data` |
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

## Traps

- **`file()` runs at plan time.** A renamed/missing `~/.ssl/ca.*` fails the plan;
  there is no fallback and no default cert.
- **The `letsencrypt` issuer's manifest still carries an `http01: {}` block** from
  the original HTTP-01 setup. It is not part of the cert-manager API, the server
  prunes it, and the `solvers` list — DNS-01 Route53 — is what actually
  validates. That is also why a host that is only reachable on the private
  gateway can still hold a public cert: validation is a `_acme-challenge` TXT
  record, so no inbound reachability is needed.
- **The route53 solver is not actually pinned to a zone.** `external_cert.tf`
  passes `zoneid = var.data["R53_ZONEID"]`, which is **not a valid field** —
  cert-manager logs `Warning: unknown field
  "spec.acme.solvers[0].dns01.route53.zoneid"` and prunes it, so the line has
  never pinned anything. The real field is `hostedZoneID`. Today it is harmless
  (the key can only reach one zone), but fix it before the key is widened.
- **The Route53 key is least-privilege and needs `route53:GetHostedZone`** if
  anything else is going to manage records with it — see
  [`../network/dns/route53_record/README.md`](../network/dns/route53_record/README.md), Trap 1.
