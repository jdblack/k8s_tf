# Network

Cluster-wide network infrastructure, applied from `stacks/core` (with one
exception: the `whisker/` submodule is instantiated by `stacks/mantle`, which is
the stack holding the authentik provider). Everything in this directory either
*is* the shared network layer or is a reusable building block consumed by other
modules.

## What it deploys

| Component | Detail |
|---|---|
| **Calico** | CNI + NetworkPolicy enforcement (`calico.tf`, `tigera-operator` chart) |
| **MetalLB** | L2 LoadBalancer pool for the LAN (`metallb.tf`, addresses from `metal_networks`) |
| **external-dns** | Publishes Services/HTTPRoutes to the internal Bind zone via RFC2136 (`external_dns.tf`, chart values in `charts.tf`). Authoritative for `vn.linuxguru.net` only — hence `dns/route53_record` for everything else |
| **NGF gateways** | `public` (192.168.0.101) and `private` (192.168.0.100) NGINX Gateway Fabric control planes + data planes in `kube-network` (`gateways.tf` + `gateway/`) |
| **Gateway API CRDs** | one-time bootstrap of `gateway.networking.k8s.io/*` (`api_gateway_config.tf`) |

Most apps do *not* live here. `kube-network` is the shared **platform** namespace:
the gateway data planes that front every namespace's HTTPS routes, external-dns,
MetalLB, and the Calico operator. Workload modules (media, auth, harbor, argo,
...) expose themselves by instantiating the `gateway/expose` submodule from their
own namespaces.

## Submodules

| Path | What it is |
|---|---|
| [`firewalls/`](firewalls/README.md) | NetworkPolicy helper library — `basic_internet`, `limited_ingress`, `allow_api` over the shared [`policy`](firewalls/policy/README.md) renderer |
| [`gateway/`](gateway/README.md) | One NGINX Gateway Fabric instance per Gateway (control plane + Gateway resource) |
| [`gateway/expose/`](gateway/expose/README.md) | One call to publish an app: HTTPS ListenerSet (+ cert/grants) and optional HTTPRoute |
| [`gateway/listener_set/`](gateway/listener_set/README.md) | App-owned HTTPS listener on a Gateway + auto cert + ReferenceGrants (used by `expose`) |
| [`gateway/http_route/`](gateway/http_route/README.md) | App-owned hostname → Service route with external-dns annotation (used by `expose`) |
| [`wireguard/`](wireguard/README.md) | VPN operator + peers (own namespace `kube-network-vpn`) |
| [`whisker/`](whisker/README.md) | Calico Whisker flow-log UI: authentik outpost + listener + netpols — instantiated by `stacks/mantle`, because it needs the authentik provider |
| [`dns/route53_record/`](dns/route53_record/README.md) | Terraform-authoritative Route53 record, for hosts external-dns cannot publish |

## Why this shapes the firewalls

`kube-network`'s shared gateway data planes are ordinary pods proxying
cross-namespace, so a gateway-fronted namespace must allow ingress from
`kube-network` (`firewalls/limited_ingress`) and an app calling a gateway URL —
SSO against `auth.<domain>` — needs `allow_to_services` on
`firewalls/basic_internet`. Composition and the decision table:
[`firewalls/README.md`](firewalls/README.md).
