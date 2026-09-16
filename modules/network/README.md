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
| **NGF gateways** | `public` and `private` NGINX Gateway Fabric control planes + data planes in `kube-network` (`gateways.tf` + `gateway/`). VIPs come from the MetalLB pool — nothing is pinned — and external-dns publishes the assigned IP into bind9, so reach them by name |
| **CRDs** | one-time bootstrap of `gateway.networking.k8s.io/*` **and** NGF's own `gateway.nginx.org/*` (`api_gateway_config.tf`) — the chart's `crds/` is install-only, so this bootstrap is what upgrades them |

Most apps do *not* live here. `kube-network` is the shared **platform** namespace:
the gateway data planes that front every namespace's HTTPS routes, external-dns,
MetalLB, and the Calico operator. Workload modules (media, auth, harbor, argo,
...) expose themselves by instantiating the `gateway/expose` submodule from their
own namespaces.

## Submodules

| Path | What it is |
|---|---|
| [`gateway/`](gateway/README.md) | One NGINX Gateway Fabric instance per Gateway (control plane + Gateway resource) |
| [`gateway/expose/`](gateway/expose/README.md) | One call to publish an app: HTTPS ListenerSet (+ cert/grants) and optional HTTPRoute |
| [`gateway/listener_set/`](gateway/listener_set/README.md) | App-owned HTTPS listener on a Gateway + auto cert + ReferenceGrants (used by `expose`) |
| [`gateway/http_route/`](gateway/http_route/README.md) | App-owned hostname → Service route with external-dns annotation (used by `expose`) |
| [`wireguard/`](wireguard/README.md) | VPN operator + peers (own namespace `kube-network-vpn`) |
| [`whisker/`](whisker/README.md) | Calico Whisker flow-log UI: authentik outpost + listener + the tier CRs the operator's own policy forces — instantiated by `stacks/mantle`, because it needs the authentik provider |
| [`dns/route53_record/`](dns/route53_record/README.md) | Terraform-authoritative Route53 record, for hosts external-dns cannot publish |

## NetworkPolicy: none, on purpose

There is **no NetworkPolicy layer in this repo** (the `firewalls/` library and every
per-app netpol were deleted 2026-09-16): every namespace reaches every other
namespace, the internet, and the API. Anything below that reads like a policy
rationale is history kept for the rebuild.

One exception is not ours: the tigera-operator (v3.32.2+) enforces its own tier
`calico-system` (`defaultAction: Deny`), so pods in `calico-system` are dropped
both ways regardless of what this repo does. `whisker/tier.tf` carries three Calico
CRs in that tier purely to let whisker and its SSO outpost function — delete them
and the UI breaks again. Details: [`whisker/README.md`](whisker/README.md) and
`.clinedocs/calico-netpols.md`.
