# egress_peer

One call renders exactly one `NetworkPolicy`, `policyTypes: ["Egress"]`, for the peers the base
builder cannot express: **a namespace *and* the pods in it, on *named* ports**. Same contract as
`egress` otherwise — callers state intent, this module decides selectors and rule order — and the
two are meant to be used on the same pod, since netpols only union.

It exists because a `to_namespaces` peer is the whole namespace on every port, and because a CIDR
peer is dead for anything in-cluster (egress is evaluated POST-DNAT —
`.clinedocs/calico-netpols.md`). Real caller:

```hcl
# harbor-core dials the private gateway to speak OIDC. The flow the policy sees is
#   harbor-core-* -> private-private-6f99f96d5f-* :443/tcp   (kube-network)
# i.e. the gateway's data plane pod, not the VIP its hostname resolves to.
module "egress_core" {
  source = "../../network/firewalls/egress_peer"

  namespace    = var.namespace
  name         = "harbor-core-gateway-egress"
  pod_selector = { "app.kubernetes.io/component" = "core" }

  to_peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = 443 }]
  }]
}
```

Renders three rules, in this order:

```
1. pods in devops-harbor, no ports                             (self)
2. ns kube-system: k8s-app=kube-dns, UDP+TCP/53                (always)
3. ns kube-network: gateway-name=private, TCP/443              (the peer)
```

Rules 1 and 2 are the same two the base builder always renders, so calling both builders on one
pod is safe: a second DNS rule is one redundant rule in the union, not a conflict.

Live call sites: `harbor/core` (`component=core`) and, since 2026-09-17, three in `argo` — repo-server
(harbor's OCI charts), argo-cd's server and argo-wf's server (the OIDC issuers) — all of them 443 on
`gateway-name=private`. The argo calls are three objects rather than one because a policy carries one pod
selector, and the three dialers share no label.

## Variables

| Variable | Type | Default | Means |
|---|---|---|---|
| `namespace` | `string` | — | Namespace whose pods this governs, and where the policy lives |
| `pod_selector` | `map(string)` | `{}` | Governed pods; `{}` = every pod in the namespace |
| `pod_selector_expressions` | `list(object)` | `[]` | `[{ key, operator, values }]` — `matchExpressions`, ANDed with `pod_selector`. `NotIn` excludes (and also matches a pod that lacks the key); an `In` here narrows the governed pods to the labelled ones |
| `name` | `string` | `null` | `metadata.name`; wins outright over `name_prefix` |
| `name_prefix` | `string` | `null` | Generated name, `<prefix>-<8 hex>`. Default prefix is `peer-egress` |
| `allow_namespace` | `bool` | `true` | This namespace's own pods — the self rule |
| `to_peers` | `list(object)` | `[]` | `{ namespace, pod_selector = <labels or null>, pod_selector_expressions = <expressions or null>, ports = [{port, protocol}] }`, one rule each |

**What it deliberately does not have:** `allow_internet`, `allow_k8s_api`, `allow_cluster`,
`to_cidrs`. Those are the base builder's curated knobs; a call that needs one of them is a call
for `egress`, and naming a CIDR is never the way to reach an in-cluster peer anyway.

## Things that bite

- **A peer with no `pod_selector` is a whole-namespace peer.** It is allowed (it is the one shape
  `to_namespaces` gets right), but this builder exists to name pods, so leaving the selector off is
  the exception and should read like one in the call.
- **Every peer gets its own rule**, because `ports` belongs to the rule in the rendered spec, not
  to the peer. Two peers with different ports are therefore two rules, not one rule with two peers
  — unlike the base builder, where every peer in a rule shares its port list.
- **A service's ClusterIP is not a peer either.** Both halves of this trap are measured: a
  ClusterIP or LoadBalancer VIP handed to `to_cidrs` matches nothing, because kube-proxy DNATs
  before the policy chain runs. Select the pod that terminates the connection.
- **An empty `ports` means every port** to that peer. Say the port.
- **The selector has to be the *target's* label, not its Service name.** NGF stamps
  `gateway.networking.k8s.io/gateway-name`; the chart-fixed app label is the usual one; a Helm
  hook Job's pods carry only `job-name` and the Job controller's labels
  (`.clinedocs/calico-netpols.md`).
