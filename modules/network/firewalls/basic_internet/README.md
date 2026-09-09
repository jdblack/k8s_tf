# `basic_internet` — namespace-wide egress firewall

Default-allow the *outbound* posture every internet-facing app namespace needs:
public internet, cluster DNS, and its own namespace. Everything else is denied
(notably: the rest of the cluster, node/LB IPs, and the LAN). This is the
module used for media, cert-manager, authentik, and harbor.

> **Direction:** Egress only. It never touches ingress — pair it with
> [`allow_ingress`](../allow_ingress/README.md) when a namespace should also
> restrict who may reach it.

## Rules it renders (`policyTypes: ["Egress"]`, whole namespace)

| Egress rule | Enabled by | Notes |
|---|---|---|
| public internet | `allow_internet` (default true) | `0.0.0.0/0` **except** `blocked_egress_cidrs` |
| cluster DNS | `allow_dns` (default true) | kube-dns pods in kube-system, UDP **and** TCP 53 |
| same namespace | `allow_to_ns` (default true) | pod-to-pod within the namespace |
| kube-network pods | `allow_to_services` (default false) | needed to reach gateway-hosted URLs (SSO etc.); see `modules/network/README.md` |
| **Kubernetes API** | `allow_to_k8sapi` (default false) | **namespace-wide** — see below |
| extra CIDRs | `egress_allow_ip_blocks` | explicit carve-outs, e.g. a LAN tuner/NAS |

`blocked_egress_cidrs` (default `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`,
`169.254.0.0/16`) is what keeps a compromised workload from trampolining into
cluster nodes, nodePorts/LBs, the control plane, or the LAN. Because Calico
evaluates egress **post-DNAT**, allow rules must match the *endpoint* IP, which
is why the k8s-API and service carve-outs track live endpoints.

## Allowing the Kubernetes API

Setting `allow_to_k8sapi = true` lets **every pod in the namespace** egress to
the API server (ClusterIP `10.96.0.1/32` + the live control-plane endpoint IPs,
port 6443 post-DNAT). It exists because the API ClusterIP/node IPs sit inside
`blocked_egress_cidrs`.

This is the right knob only when the **whole namespace** is legitimate API
consumers — e.g. `cert-manager` or Argo CD, where every component talks to the
API. If the namespace is mostly ordinary apps and just one controller needs the
API (e.g. the NGF control plane that happens to run inside the `media`
namespace), this namespace-wide grant leaks an API line to every app pod.

**For that case use the pod-scoped sibling:
[`allow_api`](../allow_api/README.md#why-pod-scoped-instead-of-basic_internetallow_to_k8sapi).**
`allow_api` emits the same DNS + API rules but only for pods matching a label
selector, and composes additively with this module (keep
`allow_to_k8sapi = false` here).

## Example

```hcl
# cert-manager: every controller/cainjector/webhook needs the API.
module "firewall" {
  source          = "../../network/firewalls/basic_internet"
  namespace       = var.namespace
  allow_to_k8sapi = true
}
```

```hcl
# media: apps must NOT reach the API; only the NGF control plane may.
module "firewall" {
  source          = "../network/firewalls/basic_internet"
  namespace       = var.namespace
  allow_to_k8sapi = false
}
module "allow_api" {
  source      = "../network/firewalls/allow_api"
  namespace   = var.namespace
  pod_selector = { "app.kubernetes.io/name" = "nginx-gateway-fabric" }
}
```

## Notes

- Rendered with the typed `kubernetes_network_policy_v1` resource so live drift
  shows up in `tofu plan`.
- Give it a unique `policy_name` if another firewall module targets the same
  namespace (NetworkPolicy names are namespace-scoped).
