# `basic_egress` — the egress firewall, namespace-wide or pod-scoped

One module for every outbound posture in this cluster: what a namespace's pods may
dial, rendered as a single `Egress` NetworkPolicy. Every rule is opt-in except the DNS
floor, so a bare call means *"this namespace talks to nothing but cluster DNS"* and
each line above that is a deliberate line in the caller.

> **Direction:** Egress only. It never touches ingress — pair it with
> [`limited_ingress`](../limited_ingress/README.md) when a namespace should also
> restrict who may reach it. Both take an optional `pod_selector`, so the two
> directions are symmetric.

## Rules it renders (`policyTypes: ["Egress"]`)

| Egress rule | Enabled by | Notes |
|---|---|---|
| one rule per namespace | `allow_namespaces` (default `[]`) | list **in render order**; your own namespace is not implied, so list it too |
| cluster DNS | always | kube-dns pods in kube-system, UDP **and** TCP 53 — the floor, not a knob |
| **Kubernetes API** | `allow_k8s_api` (default false) | ClusterIP + live control-plane endpoint IPs, TCP 6443 — see below |
| public internet | `allow_internet` (default false) | `0.0.0.0/0` **except** `blocked_egress_cidrs` |
| extra CIDRs | `allow_cidrs` (default `[]`) | explicit carve-outs, each its own rule so it wins over the `except` |

`blocked_egress_cidrs` (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`,
`169.254.0.0/16`) is internal, not a knob: it is what keeps a compromised workload from
trampolining into cluster nodes, nodePorts/LBs, the control plane, or the LAN. A
namespace that really needs a LAN address (a tuner, a NAS) asks for it by name:

```hcl
allow_cidrs = [var.deployment.metal.local_lan]
```

Because Calico evaluates egress **post-DNAT**, allow rules must match the *endpoint* IP
— that is why the API and LAN carve-outs track live endpoints/addresses rather than the
ClusterIP a pod actually dials (a pod dials `kubernetes.default:443`; the policy sees
`<node IP>:6443`).

## Postures

| Caller | Call |
|---|---|
| ordinary app, no network peers | `namespace = …` (add `allow_namespaces = [<own ns>]` if it talks to its own pods) |
| gateway-fronted app doing SSO | `allow_namespaces = ["kube-network", var.namespace]` — **kube-network first**, so the rendered spec matches the policies that predate this module |
| needs the internet (media, cert-manager, harbor, argo) | `allow_internet = true` |
| every pod needs the API (cert-manager, argo) | `allow_k8s_api = true` |
| one controller needs the API | second call with `pod_selector` + `policy_name` — see below |
| scrape-exposed only (monitoring) | `allow_cidrs = [var.pod_cidr, <node IPs>/32]` |

## Pod-scoped policies (the old `allow_api`)

Setting `pod_selector` scopes the whole policy to the pods matching it, which is how a
namespace grants one thing to a subset of its pods. This is the *only* way to do it: a
peer's `podSelector` would select pods in the guest namespace, and NetworkPolicies are
additive — so the grant has to be a second policy that unions with the namespace-wide
one.

```hcl
# Namespace-wide egress: same-ns + DNS + internet, NO API.
module "firewall" {
  source           = "../network/firewalls/basic_egress"
  namespace        = var.namespace
  allow_namespaces = [var.namespace]
  allow_internet   = true
}

# API egress for the NGF control plane ONLY.
module "firewall_api" {
  source        = "../network/firewalls/basic_egress"
  namespace     = var.namespace
  policy_name   = "allow-api-egress"
  pod_selector  = { "app.kubernetes.io/name" = "nginx-gateway-fabric" }
  allow_k8s_api = true
}

# The chart's cert-generator hook Job carries none of those labels, so it needs its own
# selector and its own policy_name -- one NetworkPolicy cannot OR two selectors.
module "firewall_api_certgen" {
  source        = "../network/firewalls/basic_egress"
  namespace     = var.namespace
  policy_name   = "allow-api-egress-certgen"
  pod_selector  = { "job-name" = module.gateway.cert_generator_job_name }
  allow_k8s_api = true
}
```

Union means the NGF controller pods get the namespace rules *and* the API rule, while
the arr/data-plane pods — matching neither selector — only get the namespace rules.

### Hook Jobs need their own selector

A Job's pods carry the Job controller's labels (`job-name`,
`batch.kubernetes.io/job-name`, `controller-uid`) and **nothing the chart specified for
its deployments**, so a `pod_selector` aimed at the controller does not cover a chart
hook. Not hypothetical: NGF's `cert-generator` is a `pre-install`/`pre-upgrade` hook, and
with media's default-deny egress its pod got `dial tcp 10.96.0.1:443: i/o timeout`,
exhausted `backoffLimit: 6`, and helm's `wait` burned the release's full timeout
(2026-09-16). The chart offers no values to label hook pods, so use the label the Job
controller applies anyway — `modules/network/gateway` publishes that name as an output.

## `api_peer_ips` — needed under a module-level `depends_on`

The endpoint IPs come from this module's own `data.kubernetes_endpoints_v1.kubernetes`
read *unless* the caller passes `api_peer_ips`. Pass them whenever the module is reached
through a module-level `depends_on` (e.g. `cert_manager`, or `storage` for the longhorn
firewall — both pulled in with `depends_on = [module.network]`). A module-level
`depends_on` covers the module's **data sources too**, so any pending change in the
depended-on module defers that read to apply time; the policy then plans a *guessed*
peer-block count (ClusterIP only, 1), the apply reads the real 2, and it aborts with

```
Provider produced inconsistent final plan ...
  .spec[0].egress[1].to: block count changed from 1 to 2
```

Read the endpoints in the **stack root** and hand them down — never hardcode the
control-plane IPs, since the endpoint entry is the peer that actually authorizes the
connection post-DNAT, so a control-plane re-IP would become a silent 6443 denial.
Invariant + evidence: `.clinedocs/calico-netpols.md`.

## Notes

- Rendered with the typed `kubernetes_network_policy_v1` resource so live drift shows up
  in `tofu plan`.
- Give it a unique `policy_name` if another firewall policy targets the same namespace
  (NetworkPolicy names are namespace-scoped). The first-come policy keeps the default
  `namespace-firewall`; a second one names itself after its direction (`namespace-ingress`,
  `namespace-egress`) or its purpose (`allow-api-egress`).
- **Removing a posture is a one-word edit now.** The module this replaced
  (`basic_internet`) had five posture booleans that all defaulted to `true`, so what a
  namespace was allowed to reach was a property of *omission*; here internet and API are
  off unless a caller asks, and `tofu plan` shows the rule disappearing.
