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
- `load_balancer_ip` — pin the data-plane Service to a MetalLB IP (the shared
  public/private gateways are pinned to the former ingress-nginx IPs so
  DNS/NAT rules keep working).
- `routes_namespace` — restrict which namespaces may attach `ListenerSet`s
  (`null` = any namespace, used by the shared gateways).

## Firewall implications

The data plane runs as ordinary pods in the gateway namespace and proxies
cross-namespace: fronted namespaces need ingress from `kube-network`
(`limited_ingress`), and apps calling gateway-hosted URLs (SSO) need egress to
kube-network pods (`basic_internet` → `allow_to_services`). Details in
[`firewalls/README.md`](../firewalls/README.md).
