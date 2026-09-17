# `cert_manager` — cert-manager, a private CA, and Let's Encrypt

Installed by `stacks/core`. Two ClusterIssuers:

| ClusterIssuer | Type | Serves |
|---|---|---|
| `letsencrypt` | `acme`, **DNS-01 via Route53** (its only solver, zone pinned) | **all 19 hosts since 2026-09-15** — the 16 declared here (`auth.vn`, `harbor`, `grafana`, `argo-wf`, `argo-cd`, plex, vaultwarden, `s3`/`master.seaweedfs`, `admin.seaweedfs`, `whisker`, five media apps) plus `ollama.vn`, `llm-embedder.vn`, `corsless.vn` from the external app-of-apps repo. Public roots, so no client setup, `.vn` included — see "Signing a `.vn` host" |
| `linuxguru-ca` | `ca`, self-signed local CA | **nothing since 2026-09-15**: its four consumers (`auth.vn`, `harbor`, `grafana`, `argo-wf`) moved to `letsencrypt` and their CA injections were deleted. Still created, still `Ready`, dormant. Expires **2027-08-14** |

## What it creates

| Resource | Detail |
|---|---|
| namespace `kube-certificates` | `var.namespace` default |
| Secret `linuxguru-ca` | `kubernetes.io/tls`; `tls.crt`/`tls.key` read with `file()` from `~/.ssl/ca.{crt,key}` — those files must exist on the machine running tofu |
| ConfigMap `linuxguru-ca`, **namespaceless** (lands in `default`) | the CA cert; no consumer left |
| Helm release `cert-manager` | pinned `v1.21.2`; `crds.enabled` + `crds.keep`, the **gateway-shim** (`enableGatewayAPI`) and ListenerSets feature gate so an annotated ListenerSet gets its `cert-<fqdn>` secret automatically; `--dns01-recursive-nameservers[-only]` at public resolvers |
| ClusterIssuer `letsencrypt` | `dns01/route53`, `hostedZoneID` from `var.data["R53_ZONEID"]`; credentials from `var.data` |
| Secret `certman-route53-letsencrypt` | the Route53 key the solver reads |
| NetworkPolicies, 2 | `cert-manager-egress` (namespace-wide: DNS + self + the API server) and `cert-manager-controller-egress` (`+ allow_internet` for the controller) — see below |

No `Certificate` is ever written by hand:
[`../network/gateway/expose`](../network/gateway/expose/README.md) annotates the
ListenerSet and the shim renders the Certificate + TLS secret in the app's own
namespace.

## Choosing the issuer

One knob: **`cert_authorities.default`** (tfvars; `letsencrypt` today; the map's
`private` key is the CA, `linuxguru-ca`). Every module takes a plain
`cert_issuer` string and ten call sites pass that key —
`stacks/core/{auth,devops,monitoring,storage}.tf` (`auth.vn`, harbor, argo-cd,
grafana, the two seaweedfs listeners) and
`stacks/mantle/{media,vaultwarden,devops,storage,observability}.tf` (plex, the
five arr apps, vaultwarden, argo-wf, `admin.seaweedfs`, whisker). No per-app
override map exists any more; a genuine exception would be new plumbing.

**Moving a host (or every host):** change the key, then
`tofu -chdir=stacks/<stack> apply`. Nothing else. The gateway-shim names the
Certificate after the Secret the listener references (`cert-<fqdn>`), so an
issuer change re-issues **in place** — same Secret, same listener, no
`certificateRefs` churn — and rollback is reverting the argument. Batching is
fine: 2026-09-15 flipped 9 hosts (3 core + 6 mantle) in one pass with all 12
public certs serving within ~4 minutes (issuance runs in parallel; the weekly
cap is 50 per *registered domain*).

Two cautions:

- **A host with in-cluster CA consumers needs those injections deleted in the
  *same apply*** as the flip. Earlier breaks that app's SSO against a
  still-private issuer; later breaks it against an already-public one, because
  the injections that *replace* the bundle (`SSL_CERT_FILE`, a
  `ca-certificates.crt` subPath mount) know nothing about public roots. That is
  what gated the last four (`auth.vn`, `harbor`, `grafana`, `argo-wf`) and why
  they could not be flipped one at a time — their listener and their CA lookup
  share a single `cert_issuer` variable. Full list and semantics: "If a private
  CA ever comes back".
- **Certificates are public.** Per-host certs publish the hostname to Certificate
  Transparency logs. A `*.vn.linuxguru.net` wildcard avoids that, but
  `listener_set` derives the Secret name from the hostname
  (`cert-*.vn.linuxguru.net` is not a legal object name) and one wildcard per
  namespace trips Let's Encrypt's duplicate-certificate limit.

## Signing a `.vn` host

Any host works: Route53 is the public authority for the **whole**
`linuxguru.net` tree. `vn.linuxguru.net` is **not** delegated, `bind9` serves the
LAN view only, and the zone holds **no `.vn` records at all** — every `.vn` name
resolves publicly because `*.linuxguru.net` is an **A alias to
`home.linuxguru.net`** that Route53 applies at any depth. So no `.vn` wildcard,
extra zone or NS delegation is needed, and deleting a `.vn` record changes
nothing publicly. The `_acme-challenge.<host>.vn...` TXT coexists with that
wildcard because they are different RR types.

## The dormant CA

**Status: dormant** — three inert objects cost nothing to leave alone
(ClusterIssuer, Secret, namespaceless ConfigMap). What *does* bite:
`var.ca_certfile`/`var.ca_keyfile` default to `~/.ssl/ca.{crt,key}`, read with
`file()` at plan time, so they are a **standing plan-time dependency of
`stacks/core`** and deleting them fails the next plan of any kind. The CA expires
**2027-08-14** (issued 2026-08-14), so a reintroduced host would need it
regenerated *and* trust injected by hand into every consumer.

It lives outside Terraform (`~/.ssl/gencert`); this module only consumes it. It
is self-signed, `CN=vn.linuxguru.net`, one year:

```sh
# ~/.ssl/gencert — the invocation that made the current ca.crt
openssl req -x509 -new -nodes -key ca.key -sha256 -days 365 -out ca.crt \
  -config openssl.cnf \
  -subj "/C=VN/ST=Ho Chi Minh City/L=Ho Chi Minh City/O=Linuxguru/CN=vn.linuxguru.net/emailAddress=jblack@linuxguru.net"
```

`~/.ssl/openssl.cnf` carries the CA extensions (`basicConstraints=CA:TRUE`, key
usage, SANs) — without it the "CA" is just a leaf cert and nothing validates it.
Rotating the CA re-issues every certificate it signed, so keep the old `ca.crt`
until every client is updated.

The CA's *name* is not a literal anywhere: `ca.tf` reads it from
`var.data["cert_issuer"]` (tfvars `cert.cert_issuer`) and derives all five object
names from it, so that key is **not** dead — deleting it renames the Secret,
ClusterIssuer and ConfigMap.

## Egress: two policies, and the API grant is namespace-wide

`egress.tf`, written to the layer's method (no separate rollout step — the module owns its own call):

| Policy | Selects | Grants |
|---|---|---|
| `cert-manager-egress` | **every** pod (`podSelector: {}`) | own namespace + DNS + the API server (both halves: ClusterIP :443, control-plane :6443) |
| `cert-manager-controller-egress` | `name=cert-manager` + `component=controller` | the public internet |

The base carries the API grant for the *namespace* rather than three pod-scoped calls, and that is the
deliberate part: everything this chart renders is an API client (the controller's watches and leader
election, cainjector's writes, the webhook's `subjectaccessreviews`, the `startupapicheck` hook Job) —
and the hook is a pod with only `job-name` labels, i.e. the exact shape that armed NGF's cert-generator
hook in `media`. A closed floor plus three grants would look tidier and break on the next
`helm upgrade`.

The internet grant is on the controller alone, and it is not optional: ACME registration/renewals at
`acme-v02.api.letsencrypt.org`, the Route53 API for the DNS-01 TXT, and the public recursors
`locals.tf` pins (`--dns01-recursive-nameservers-only` sends *all* DNS-01 lookups to 8.8.8.8/1.1.1.1,
never to the pod's LAN resolver). cainjector and the webhook stay API-only.

**Measured, because this namespace is invisible to flow logs** — a 30-day Whisker window holds **zero**
records for `kube-certificates` (watches never end and are never emitted; `.clinedocs/flow-logs.md`),
so the guests came from configuration plus live probes:

- API: nine `cert-manager-*` ClusterRoleBindings on the `cert-manager` ServiceAccount, and the log's own
  reflectors (`"Caches populated" type=*v1.Gateway/*v1.HTTPRoute`) — informers are a client by
  construction. `curlimages/curl` pods carrying each selector, after the apply, against
  `https://10.96.0.1:443/api`: **403 both** (reachable, unauthorized), the API hop appearing in Whisker as
  `→ PRIVATE NETWORK:6443 Allow` (post-DNAT to `192.168.0.74`).
- Internet: every ACME `order` is `valid` from 2d9h ago — DNS-01 via Route53, i.e. a public API call —
  and the controller's log has `verified existing registration with ACME server`. Same probes:
  `acme-v02.api.letsencrypt.org` **200** and `https://1.1.1.1` **301** from the controller-selected pod,
  and `nslookup … 8.8.8.8` / `1.1.1.1` answer (the load-bearing case — renewals die silently without it).
- Lease renewals are the reason this is not deferrable: certs renew ~17 days out, so a missing peer
  looks like nothing until the first renewal attempt.
- Negative controls, both pods: LAN `192.168.0.1` and a `media` pod on `:8989` time out, and the
  unlabelled-base pod (`app=egress-probe`) gets **no** internet at all while still reaching the API —
  i.e. the floor is real and the internet grant is not inherited.
- Post-apply plan: `No changes`. Neither policy touches the running pods (netpols union, and both
  selectors keep DNS + self).

## Still no ingress here, on purpose

The reason this namespace has never had **ingress** rules stands: the kube-apiserver calls the
cert-manager webhook from the nodes — host traffic, not a pod namespace — so any ingress restriction
here breaks issuance cluster-wide. The pods' `prometheus.io/scrape` annotations are inert
(kube-prometheus-stack ignores annotations; there is no ServiceMonitor and no `up{namespace=…}` series),
so nothing scrapes them either, and the ingress half has **no guests at all** to name.

## If a private CA ever comes back

Nothing needs one today: every host is public, and the CA's only remaining
footprint is the ClusterIssuer plus the `kube-certificates/linuxguru-ca` Secret
and `default/linuxguru-ca` ConfigMap. If one is reintroduced, trust must be
injected **by hand** into each consumer — there is no cluster-wide switch, and a
container never reads the node's trust store.

**First question for each consumer: does the knob *add to* or *replace* the
container's bundle?**

| Consumer | Knob (where it lived) | Semantics | Removal timing |
|---|---|---|---|
| Harbor | `caBundleSecretName` → Secret with a `ca.crt` key (`modules/harbor/core/{main,locals,secrets}.tf`) | **adds** an extra bundle Harbor loads on top | any time |
| Argo CD (server) | `argocd-cm` → `oidc.config.rootCA` (`modules/argo/mantle/argo-cd/oauth2.tf`) | roots for the **OIDC issuer**; documented as *additional*, but augment-vs-replace was never verified here (see below) | any time |
| Argo CD (repo-server) | `argocd-tls-certs-cm`, mounted at `/app/config/tls` | **adds** a per-hostname trust store for chart pulls | any time |
| Grafana | `SSL_CERT_FILE` → CA file mounted at `/etc/grafana/certs` (`modules/monitoring/prometheus/{locals,grafana}.tf`) | **REPLACES** the Go trust bundle | same apply as the flip |
| Argo Workflows | `ca-certificates.crt` **subPath mount** from a mirrored ConfigMap (`modules/argo/mantle/argo-workflows/{locals,oauth2}.tf`) | **REPLACES** the container bundle (chart 0.46.x has no `server.sso.rootCA`) | same apply as the flip |

**Argo CD is the painful one — two independent trust stores, on different pods,
neither visible in the Application YAML:**

1. **OIDC trust** — `argocd-cm` → `oidc.config.rootCA`, used when `argocd-server`
   talks to `auth.vn`. It is written with `kubernetes_config_map_v1_data`, a
   **merge** into the chart-owned `argocd-cm`, so removing the key from HCL is
   not always enough — confirm the live object (`kubectl -n argo get cm
   argocd-cm -o json | jq -r '.data["oidc.config"]' | grep -i rootca`). A stale
   value is a landmine: harmless while the CA validates, then a broken handshake
   (`x509: cannot validate certificate`) the day it expires. And `argocd-server`
   parses OIDC config **once, at startup** — `rollout restart
   deploy/argo-cd-argocd-server` or you are testing the previous config.
   *Unverified:* whether `rootCA` augments the system pool or replaces it. Test
   before relying on it: if OIDC works against the private issuer **and** a
   public one it augments; if it breaks the moment the issuer goes public it
   replaced it. This repo removed `rootCA` in the flip apply, so it never
   depended on the answer.
2. **Registry trust** — `argocd-tls-certs-cm`, keys are hostnames and values PEM,
   mounted on the **repo-server** pod (`argo-cd-argocd-repo-server`). Not
   covered by `rootCA`, not fixed by
   restarting `argocd-server`.

   **Its absence was a real, silent breakage:** the Helm repo was registered with
   verification on (`insecure` unset) while this ConfigMap was empty, so every
   chart pull failed and the two Applications using it (`corsless`,
   `llm-embedder`) sat `Unknown` for months, unalerted:
   `tls: failed to verify certificate: x509: certificate signed by unknown
   authority` on `https://harbor.vn.linuxguru.net/v2/.../tags/list`. Moving the
   registry to a public issuer fixed it for free. Symptom and fix site:
   (`kubectl -n argo get applications -o json | jq -r
   '.items[].status.conditions[]?.message' | grep -i x509`) and (`kubectl -n argo
   get cm argocd-tls-certs-cm -o jsonpath='{.data}'`).

**Harbor:** `caBundleSecretName` takes a **Secret whose key is `ca.crt`**, not a
ConfigMap (Harbor validated the OIDC issuer with `oidc_verify_cert = true`).
Harbor's OIDC config lives in Harbor's **database** (`harbor_config_auth`), so
neither `grep` nor `kubectl get -o yaml` reveals it — the failure mode is a
broken login, not a broken registry.

**Grafana and Argo Workflows** mirrored the CA into their own namespace first
(a ConfigMap volume can only mount from the pod's own namespace, and the CA lived
in `default`). Grafana pointed `SSL_CERT_FILE` at the file; Workflows mounted it
*over* `/etc/ssl/certs/ca-certificates.crt` with `subPath: tls.crt` — and a
subPath mount is snapshotted at pod start, so a rotated CA needs a rollout too.
On chart ≥ 1.x / app ≥ v4 use Workflows' `server.sso.rootCA`, which augments
instead of replacing.

**Prove nothing is left** — one sweep beats reading every module. Search every
ConfigMap and Secret whose contents hold the CA (fragment = any chunk of its
base64 body):

```sh
CAF='MIIGETCCA/mgAwIBAgIUSqMuDS9B7KQXzQvXUGQ0j7YpDSc'
kubectl get cm -A -o json | jq -r --arg f "$CAF" \
  '.items[] | (.data // {}) as $d | select([$d[]] | any(contains($f))) | "cm " + .metadata.namespace + "/" + .metadata.name'
kubectl get secret -A -o json | jq -r --arg f "$CAF" \
  '.items[] | (.data // {}) as $d | select([$d[] | @base64d] | any(contains($f))) | "secret " + .metadata.namespace + "/" + .metadata.name'
```

Mind the `@base64d` on the Secret half: Secret values are base64, so a literal
substring match finds nothing and looks like a clean sweep. After 2026-09-15 the
only hits are the CA itself (`default/linuxguru-ca`,
`kube-certificates/linuxguru-ca`).

Two places a CA lingers outside the cluster: the **nodes**
(`/usr/local/share/ca-certificates/` + `update-ca-certificates`, applied by
`initial_setup.yml` in the k8s repo) and **`~/.ssl/ca.crt` on the operator box**,
which `var.ca_certfile` reads at plan time.

## Traps

- **`file()` runs at plan time.** A renamed/missing `~/.ssl/ca.*` fails the plan;
  there is no fallback and no default cert.
- **DNS-01 needs no inbound reachability.** Validation is a `_acme-challenge` TXT
  record, so a host served only by the private gateway can still hold a
  publicly-trusted cert (vaultwarden, sonarr).
- **Split-horizon DNS is why two settings here are load-bearing.** The cluster
  resolves through the LAN resolver, authoritative for `vn.linuxguru.net`
  (bind9) and blind to the challenge TXT (which lives in the Route53
  `linuxguru.net` zone). Hence `hostedZoneID` on the solver — without it zone
  discovery climbs SOA records to `vn.linuxguru.net`, which has no Route53
  counterpart, and the challenge dies with `zone vn.linuxguru.net not found in
  Route 53` — plus `--dns01-recursive-nameservers` and
  `--dns01-recursive-nameservers-only` in `locals.tf`, without which the
  self-check asks bind9's NS for a TXT only Route53 has.
- **`Waiting for DNS-01 challenge propagation` for a minute is normal.** The
  solver writes the TXT with a 10s TTL and cert-manager polls the public view;
  the challenge reaches `valid` on its own (~90s; the 9-host batch took ~4 min
  end to end). A challenge sitting `pending` ~3 min while others finish is just
  the self-check waiting.
- **Rate limits are per registered domain, and nowhere near current use.** 50 new
  certs per registered domain per week, 5 *duplicate* certs per week, 5 failed
  validations per hostname per hour; renewals (at 2/3 of lifetime) are exempt
  from the 50. The 2026-09-15 batch of 9 was ~¼ of the weekly cap, so batching is
  cheap — but a broken solver burns the 5-failures-per-hour budget fast, and
  there is **no staging ClusterIssuer** (`server` is hardcoded to the production
  directory). Iterating means temporarily pointing `server` at
  `.../staging/directory`, whose certs are untrusted — don't leave it applied.
- **A failed renewal is invisible today.** cert-manager serves `certmanager_*` on
  `:9402`, but nothing here creates a `ServiceMonitor` or an expiry
  `PrometheusRule`, so a silent solver failure surfaces as an expired cert on day
  90 — not as an alert. Renewal at 2/3 of lifetime leaves ~30 days to notice by
  hand.
- **`*.linuxguru.net` is an A alias, and that is load-bearing both ways.** Every
  `.vn` name resolves publicly because of it, so deleting `.vn` records cannot
  make them NXDOMAIN — the wildcard is the only lever. Do **not** convert it to a
  CNAME: a wildcard CNAME answers `cnameStrategy: Follow` queries for
  `_acme-challenge.<host>`, whereas an A alias leaves TXT queries as plain
  NODATA. The issuer keeps the default `cnameStrategy: None`.
- **`zoneid` was never an API field.** The real field is `hostedZoneID`;
  `external_cert.tf` used to pass `zoneid`, which the server pruned, so nothing
  was ever pinned. Pinning also keeps the least-privilege key honest: it can only
  touch `Z3FM4Y4P2572E4`.
- **The Route53 key needs `route53:GetHostedZone`** if anything else manages
  records with it — see
  [`../network/dns/route53_record/README.md`](../network/dns/route53_record/README.md),
  Trap 1.




