# Network

Cluster-wide network infrastructure, applied from `stacks/core`. Everything in
this directory either *is* the shared network layer or is a reusable building
block consumed by other modules.

## What it deploys

| Component | Detail |
|---|---|
| **Calico** | CNI + NetworkPolicy enforcement (`calico.tf`, `tigera-operator` chart) |
| **MetalLB** | L2 LoadBalancer pool for the LAN (`metallb.tf`, addresses from `metal_networks`) |
| **external-dns** | Publishes Services/HTTPRoutes to the internal Bind zone via RFC2136 (`external_dns.tf`) |
| **NGF gateways** | `public` (192.168.0.101) and `private` (192.168.0.100) NGINX Gateway Fabric data planes in `kube-network` (`gateways.tf` + `gateway/`) |
| **Gateway API CRDs** | one-time bootstrap of `gateway.networking.k8s.io/*` (`api_gateway_config.tf`) |

Most apps do *not* live here. `kube-network` is the shared **platform** namespace:
the gateway data planes that front every namespace's HTTPS routes, external-dns,
MetalLB, and the Calico operator. Workload modules (media, auth, harbor, argo,
...) expose themselves by instantiating the `gateway/listener_set` + `gateway/http_route`
submodules from their own namespaces.

## Submodules

| Path | What it is |
|---|---|
| [`firewalls/`](firewalls/README.md) | NetworkPolicy helper library — `basic_internet`, `limited_ingress`, `allow_api` over the shared [`policy`](firewalls/policy/README.md) renderer |
| [`gateway/`](gateway/README.md) | One NGINX Gateway Fabric instance per Gateway (control plane + Gateway resource) |
| [`gateway/expose/`](gateway/expose/README.md) | One call to publish an app: HTTPS ListenerSet (+ cert/grants) and optional HTTPRoute |
| [`gateway/listener_set/`](gateway/listener_set/README.md) | App-owned HTTPS listener on a Gateway + auto cert + ReferenceGrants (used by `expose`) |
| [`gateway/http_route/`](gateway/http_route/README.md) | App-owned hostname → Service route with external-dns annotation (used by `expose`) |
| [`wireguard/`](wireguard/README.md) | VPN operator + peers (own namespace `kube-network-vpn`) |
| [`dyndns/`](dyndns/README.md) | Route53 dynamic-DNS updater |

## Why the firewalls care about this module

The shared gateway **data planes are regular pods in `kube-network`**, and they
proxy cross-namespace into every app namespace. Two consequences that drive the
design of the firewall library:

- **Ingress**: any gateway-fronted namespace must allow `kube-network` in its
  ingress policy or its routes break (see `firewalls/limited_ingress`).
- **Egress**: an app that talks to a gateway-hosted URL (e.g. SSO against
  `auth.vn.linuxguru.net`) connects to the gateway data plane post-DNAT, so it
  needs the `allow_to_services` knob on `firewalls/basic_internet`.

NetworkPolicies are **additive** — an ingress policy, a namespace-wide egress
policy, and a pod-scoped egress policy can all coexist in one namespace (each
needs a unique `policy_name`). See `firewalls/README.md` for the decision table.
