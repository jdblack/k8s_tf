# Firewalls

Reusable NetworkPolicy helpers. Every module here ultimately renders a typed
`kubernetes_network_policy_v1` resource (NOT `kubectl_manifest`) so that
`tofu plan` diffs against live state and flags out-of-band drift — a
kubectl-managed NetPol whose spec was edited behind tofu's back was previously
invisible to planning (this actually happened to the seaweedfs policy).

The presets below build explicit **rule objects** and hand them to
[`policy/`](policy/README.md), which is the single renderer — so the
rule → resource translation (and its drift-visibility) lives in one place.

## Decision table

| Module | Direction | Scope | What it allows | Key variables |
|---|---|---|---|---|
| [`basic_egress`](basic_egress/README.md) | **Egress** | whole namespace, or a `pod_selector` subset | cluster DNS + exactly the peers the caller asks for: namespaces, the k8s API, the internet, explicit CIDRs | `allow_namespaces`, `allow_k8s_api`, `allow_internet`, `allow_cidrs`, `pod_selector` |
| [`limited_ingress`](limited_ingress/README.md) | **Ingress** | whole namespace, or a `pod_selector` subset | connections from a configured list of namespaces + source CIDRs (LAN/LB clients, or `0.0.0.0/0` minus the cluster ranges); everything else denied | `allowed_ingress_namespaces`, `allowed_ingress_cidrs`, `pod_selector` |

Both target `podSelector: {}` (the whole namespace) by default and take an optional
`pod_selector` for a pod-scoped supplement — the two directions are symmetric. A
namespace-wide policy plus a pod-scoped one is how a grant is limited to a subset of
pods: NetworkPolicies union, so a differently-named pod-scoped policy *adds* to the
namespace-wide one. See
[`basic_egress` → pod-scoped policies](basic_egress/README.md#pod-scoped-policies-the-old-allow_api)
and [`limited_ingress`](limited_ingress/README.md#pod_selector--pod-scoped-supplement).

## Similar-feature cross-references

Where the API grant lives is the one scope decision that matters:

- `basic_egress.allow_k8s_api = true` — **namespace-wide**: *every* pod in the namespace
  may egress to the API server. Right call when the whole namespace is trusted API
  consumers (cert-manager, Argo CD).
- the same module with `pod_selector` + `policy_name` — **pod-scoped**: *only* the
  matching pods may. Right call when a namespace is mostly apps that must NOT reach the
  API but hosts one controller that must (the NGF control plane inside `media`, the
  authentik worker, and — with `job-name` — the chart's hook Jobs).

Rule of thumb: **prefer the pod-scoped call** unless every workload in the namespace
legitimately calls the API.

## Composing policies

NetworkPolicies in Kubernetes are **additive (union)**, so this library is
meant to be combined, not picked one-per-namespace:

- `limited_ingress` + `basic_egress` = full posture for a gateway-fronted app
  (who may reach me + where I may go).
- `basic_egress` (API off) + a pod-scoped `basic_egress` = namespace lockdown with a
  single pod-scoped API exception.

Every module takes a `policy_name` (default `namespace-firewall`); NetworkPolicy names
are unique *per namespace*, so give each policy in the same namespace a distinct name.

## History (names only — nothing is enforced by the old ones)

- **`basic_internet` → `basic_egress`** and **`allow_api` folded into it** (2026-09). The
  old egress module's five posture booleans all defaulted to `true`, so what a namespace
  could reach was a property of *omission*, and `allow_api` was the same renderer with a
  `pod_selector`. One module now takes a `pod_selector` and only DNS is implicit. Renames
  and paths only: call-site module names, resource labels and `policy_name`s did not move
  (`moved` blocks carried the state), so no NetworkPolicy was created or destroyed.
- **`namespace_only` is gone**, replaced by `limited_ingress` with
  `allowed_ingress_namespaces = [var.namespace]` — the same posture with a guest
  list, and typed instead of `kubectl_manifest`.
- **`allow_ingress` → `limited_ingress`** (2026-09). The old name read like a
  blanket "allow ingress" when the module is actually a lockdown with a guest
  list. Docs/paths only: the module call name, resource label and default
  `policy_name` did not move, so the rename caused no NetworkPolicy
  create/destroy. `allowed_ingress_cidrs` arrived at the same time, so a
  namespace whose LoadBalancer is reached from outside the cluster (where the
  source is never a pod) can stay open while every cluster pod is denied.
