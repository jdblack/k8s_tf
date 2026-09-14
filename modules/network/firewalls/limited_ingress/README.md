# `limited_ingress` — ingress firewall with a namespace/CIDR guest list

Restrict who may open connections *into* this namespace. Pods in the namespace
accept ingress only from the namespaces listed in `allowed_ingress_namespaces`
and the source CIDRs in `allowed_ingress_cidrs`; everything else is dropped.

> **Direction:** Ingress only. Pair it with
> [`basic_internet`](../basic_internet/README.md) for the matching egress posture.

## When to use

The natural profile for anything **served through a shared gateway**: the gateway
data planes live in `kube-network` and proxy into your namespace, so that namespace
must appear in the list, plus `monitoring` if Prometheus scrapes you. Example from
seaweedfs:

```hcl
module "firewall" {
  source = "../../network/firewalls/limited_ingress"

  namespace = var.namespace   # e.g. "kube-storage"
  allowed_ingress_namespaces = [
    var.namespace,   # seaweed components talk to each other
    "kube-network",  # private-gateway data plane fronts S3/admin/master for LAN clients
    "monitoring",    # Prometheus ServiceMonitor scrapes
  ]
  # only when the namespace is also reached directly via a LoadBalancer.
  # A LAN-only peer is `{ cidr = "192.168.0.0/24" }`; a LoadBalancer that is
  # ALSO internet-exposed (WAN port-forward, where the source is a public peer
  # address) uses "everything outside the cluster":
  # allowed_ingress_cidrs = [
  #   { cidr = "0.0.0.0/0", except = ["10.244.0.0/16", "10.96.0.0/12"] },
  # ]
}
```

- Namespaces: add the namespace itself if its pods talk to each other
  (`[var.namespace]` = same-namespace-only, the former `namespace_only` module),
  `kube-network` if it is exposed via a ListenerSet/HTTPRoute, `monitoring` if it
  has ServiceMonitors.
- CIDRs: needed only for a **LoadBalancer** reached directly from outside the
  cluster (media's plex / torrent / gateway LBs). A LAN client or an internet peer
  is not a pod, so no `namespaceSelector` can ever match it — this peer type is what
  keeps the LB reachable while every cluster pod stays denied. Use
  `0.0.0.0/0` + `except` when the LB is also WAN-exposed (port-forwarded), since the
  source is then a public address, not the LAN. The `except` ranges are this
  cluster's own ranges (Calico pods `10.244.0.0/16`, ClusterIPs `10.96.0.0/12`) and
  must sit inside `cidr`.

## Semantics

- Scope: `podSelector: {}` (whole namespace) unless `pod_selector` is set, in which
  case the policy applies only to those pods. `policyTypes: ["Ingress"]`.
- Each `allowed_ingress_namespaces` entry becomes one `namespaceSelector` peer (any
  pod in that namespace, any port); each `allowed_ingress_cidrs` entry becomes one
  `ipBlock` peer (any host inside its `cidr` and outside its `except`, any port). All
  peers live in a single ingress rule.
- **Both** lists empty renders a bare ingress policy = **deny all ingress**
  (deliberately no "empty rule means allow all" footgun).
- Rendered with the typed `kubernetes_network_policy_v1` resource (drift-visible).

### `pod_selector` — pod-scoped supplement

`pod_selector` scopes the policy to specific pods (the **destination**). Use it to
let an extra namespace reach **one** target without opening the whole namespace to
it: call the module once namespace-wide with a tight guest list, then a second time
with the target's labels and the extra namespace. NetworkPolicies union, so the
target gets both and everything else gets only the first. **Media** uses this so
`kube-network` (which hosts the internet-facing shared gateways) may reach only
plex:

```hcl
# namespace-wide: media + VPN + LAN/internet, deliberately NO kube-network
module "firewall_ingress" {
  source                     = "../network/firewalls/limited_ingress"
  namespace                  = var.namespace
  policy_name                = "namespace-ingress"
  allowed_ingress_namespaces = [var.namespace, "kube-network-vpn"]
  allowed_ingress_cidrs = [
    { cidr = "0.0.0.0/0", except = ["10.244.0.0/16", "10.96.0.0/12"] },
  ]
}

# pod-scoped supplement: kube-network -> the plex pods only
module "firewall_ingress_plex" {
  source                     = "../network/firewalls/limited_ingress"
  namespace                  = var.namespace
  policy_name                = "namespace-ingress-plex"
  pod_selector               = { "app.kubernetes.io/name" = "plex-media-server" }
  allowed_ingress_namespaces = ["kube-network"]
}
```

Each call needs its own `policy_name` (names are per-namespace). Note the
scoping is on the **destination** — a peer's own `podSelector` would select the
*source* pods in the guest namespace instead.

## Naming

Renamed `allow_ingress` → `limited_ingress` (2026-09, docs/paths only) and it
replaces the old `namespace_only` module, which was exactly this with
`allowed_ingress_namespaces = [var.namespace]`. Full story in
[`../README.md`](../README.md).

## See also

- [`basic_internet`](../basic_internet/README.md) — the matching egress module.
- [`firewalls/README.md`](../README.md) — decision table and composition notes.
