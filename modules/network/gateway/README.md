# Gateway — one NGINX Gateway Fabric instance

Deploys a single NGINX Gateway Fabric (NGF) **control plane** (Helm chart
`nginx-gateway-fabric`) plus a `Gateway` resource with a plain-HTTP listener
that drops requests. Each gateway instance gets its own `GatewayClass` and
controller name, so multiple instances can coexist (the shared `public` /
`private` gateways in `kube-network`, and `media-private` inside the media
namespace).

The caller owns the namespace — this module never creates one.

## The Gateway is app-agnostic

The `Gateway` exposes no HTTPS listeners itself. **Each app owns its exposure**
by instantiating these two submodules from its own namespace:

| Submodule | Creates |
|---|---|
| [`listener_set/`](listener_set/README.md) | an HTTPS `ListenerSet` on the gateway + auto-provisioned cert + cross-namespace `ReferenceGrant`s |
| [`http_route/`](http_route/README.md) | the `HTTPRoute` (hostname → backend Service) + external-dns annotation |

## Variables that matter

- `name` / `release_name` — unique per instance. `name` also names the
  cluster-scoped `GatewayClass`; `release_name` avoids Helm resource collisions
  when several instances share one namespace (`ngf-public` / `ngf-private`).
- `watch_namespaces` — scope the controller to specific namespaces (`[]` =
  all). The controller always watches its own namespace.
- `load_balancer_ip` — pin the data-plane Service to a MetalLB IP when passed.
  **Unset for every gateway in the repo** (`kube-network`'s `public`/`private`
  and `media-private`): the addresses float, external-dns (and vaultwarden's
  Route53 record) read the live Service, and no address is frozen in tfvars
  (2026-09-16). It stays as the re-pin escape hatch if a router NAT rule ever
  has to point at a fixed address.
- `routes_namespace` — restrict which namespaces may attach `ListenerSet`s
  (`null` = any namespace, used by the shared gateways).

## NetworkPolicy implications

The data plane runs as ordinary pods in the gateway namespace and proxies
cross-namespace. **Nothing is enforced in here yet**: this namespace has no policy of its own, and
the ingress half covers only two namespaces — `kube-storage` (namespace-wide, accepting the gateway
pod on the backend ports its HTTPRoutes name) and `longhorn-system` (pod-scoped, for the Prometheus
scrape of `longhorn-manager`), both 2026-09-17 — so every other fronted namespace still accepts
traffic from anywhere. The egress half is real, in both directions:

- an app calling a gateway-hosted URL needs egress to *this* namespace. `devops-harbor` states it
  (`harbor/core/egress.tf`): an `egress_peer` on 443 selected by the chart's
  `gateway.networking.k8s.io/gateway-name` label, for harbor-core's OIDC — and every other OIDC
  consumer here (`grafana`, `argo`, both on `auth.<domain>`) will need the same peer.
- the controller itself needs the API server for its Gateway API watches. Those are long-lived
  connections that a flow log never shows, so an empty Whisker window is not evidence of absence:
  `media` grants it by pod selector (`ngf-egress`), and the cert-generator hook Job needs a
  *separate* policy, because its pod template sets no labels at all — only `job-name`
  (`cert_generator_job_name` in `outputs.tf` exists for that call).
