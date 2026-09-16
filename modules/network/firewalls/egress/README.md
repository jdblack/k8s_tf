# egress

One call renders exactly one `NetworkPolicy` with `policyTypes: ["Egress"]`. Callers state
intent; the module decides selectors, CIDRs and rule order.

```hcl
module "egress_for_gateway_hook" {
  source = "../network/firewalls/egress"

  namespace    = var.namespace
  policy_name  = "gateway-hook-egress"
  pod_selector = { "job-name" = "ngf-nginx-gateway-fabric-cert-generator" }
  to_k8s_api   = true
}
```

## Variables

| Variable | Type | Default | Means |
|---|---|---|---|
| `namespace` | `string` | — | Namespace whose pods this governs, and where the policy lives |
| `pod_selector` | `map(string)` | `{}` | Governed pods; `{}` = every pod in the namespace |
| `policy_name` | `string` | `"namespace-egress"` | `metadata.name`; one call, one object |
| `to_namespaces` | `list(string)` | `[]` | Whole-namespace peers, by name, no pod selector |
| `to_k8s_api` | `bool` | `false` | `TCP/6443` to the API server's ClusterIP and the control-plane addresses |
| `to_cluster` | `bool` | `false` | The pod CIDR and the service CIDR, wholesale |
| `to_internet` | `bool` | `false` | `0.0.0.0/0` except RFC1918 + link-local |
| `to_cidrs` | `list(string)` | `[]` | Extra CIDRs, one `ipBlock` peer each (LAN, NAS, off-cluster) |
| `api_peer_ips` | `list(string)` | `[]` | Override for `to_k8s_api`; empty = read from the cluster |

## What always renders

Two rules, in this order, unconditionally — no variable turns them off:

1. **Self:** every pod in `var.namespace`.
2. **DNS:** `UDP+TCP/53` to `kube-system` / `k8s-app=kube-dns`.

A pod-scoped policy that silently loses DNS looks exactly like a broken application, which is
why there is no knob for it.

Then, in this frozen order (this list *is* the rendered spec, so changing it rewrites every
policy in the repo):

```
self → DNS → to_namespaces → API → cluster → internet → to_cidrs
```

## Semantics

- **Post-DNAT.** Calico evaluates egress *after* DNAT, so peers are pod IPs and real container
  ports — never Services, never Service ports. That is why `to_k8s_api` is `ipBlock`-shaped,
  and why the API rule names the Service's `cluster_ip` (`10.96.0.1/32`) *and* the control-plane
  addresses behind it (`192.168.0.74/32`), ClusterIP first.
- **`to_internet` never reaches the LAN** — it subtracts RFC1918 and link-local. For the LAN,
  or any off-cluster host, use `to_cidrs`. The LAN's CIDR is `deployment.network.host_cidr` in
  the tfenv (`192.168.0.0/24`, declared 2026-09-16); nothing in-cluster stores a netmask (Node
  `status.addresses` are /32 InternalIPs, the MetalLB pool is a range), so a module can never
  *read* it, only be passed it.
- **CIDRs are read, not passed.** `to_cluster` reads `kube-system/kubeadm-config`
  (`podSubnet`/`serviceSubnet`); `to_k8s_api` reads the `kubernetes` Service and Endpoints in
  `default`. Both reads are `count`-gated, so a floor-only call is a pure
  `NetworkPolicy` write with no cluster reads at all.
- **`policyTypes: ["Egress"]` always.** A policy that also typed `Ingress` would deny every
  inbound flow to the selected pods.

## Recipes

**Hosting a Gateway** (control plane + certificate-generator hook), both in the gateway's own
namespace:

```hcl
module "egress_for_gateway" {
  source       = "../network/firewalls/egress"
  namespace    = var.namespace
  policy_name  = "gateway-egress"
  to_k8s_api   = true
}

module "egress_for_gateway_hook" {
  source       = "../network/firewalls/egress"
  namespace    = var.namespace
  policy_name  = "gateway-hook-egress"
  pod_selector = { "job-name" = "ngf-nginx-gateway-fabric-cert-generator" }
  to_k8s_api   = true
}
```

**A namespace that talks to the internet (and so needs the API):**

```hcl
to_namespaces = ["kube-network"]  # the gateway data plane
to_internet   = true
to_k8s_api    = true
```

**A namespace that only talks to itself:** pass nothing. `namespace` is the whole call.

**Reaching the LAN** — at a stack call site the value is already in scope; inside an app module
the stack has to pass `host_cidr` in:

```hcl
to_cidrs = [var.deployment.network.host_cidr]  # 192.168.0.0/24
```

**Reaching an off-cluster NAS** (a single host, not the whole LAN):

```hcl
to_cidrs = ["192.168.0.20/32"]
```

Each entry becomes its own `ipBlock` peer; there is no port knob, so it is all ports to that
host. Reach for `to_internet = true` only for traffic that genuinely leaves the network —
it will *not* reach the LAN.

## What it cannot do

- **Ingress.** Not a bug: there is no safe default ingress shape, and a wrong one is a
  deny-all.
- **Port-scoped peering** (`namespace + pod → namespace + pod, port N`) — e.g. the authentik
  outposts. Widening that to a whole-namespace peer is a privilege increase, so a caller
  needing it writes its own policy.
- **Per-peer ports.** Ports apply to the whole rule, not to one `to` entry.

`../../whisker/tier.tf` is not a precedent for any of this: those are Calico CRs in the
operator's own tier, needed because `calico-system` denies before the `default` tier where these
policies compile.
