# `allow_api` — pod-scoped egress to the Kubernetes API

Let a **specific set of pods** (matched by `pod_selector`) egress to the
Kubernetes API server — DNS + the API ClusterIP/control-plane endpoints. Every
other pod in the namespace is untouched by this policy.

> **Direction:** Egress. **Scope:** a pod subset, not the whole namespace —
> this module is the only firewall in this directory that doesn't target
> `podSelector: {}`.

## Why pod-scoped instead of `basic_internet.allow_to_k8sapi`?

[`basic_internet`](../basic_internet/README.md#allowing-the-kubernetes-api)
offers `allow_to_k8sapi`, which grants API egress to **every pod in the
namespace**. That is the convenient knob, but it's namespace-wide: any pod in
the namespace — even an app with no business near the API — inherits an open
line to the API server.

Use `allow_api` when a namespace is mostly ordinary workloads but must host one
API-consuming controller. The canonical example is `media`: the `media-private`
NGINX Gateway Fabric **control plane** lives inside the media namespace and must
reach the API, but radarr/sonarr/plex/etc. must not.

### The split in `media`

```hcl
# Namespace-wide egress: same-ns + DNS + internet, NO API.
module "firewall" {
  source          = "../network/firewalls/basic_internet"
  namespace       = var.namespace
  allow_to_k8sapi = false
}

# API egress for the NGF control plane ONLY.
module "allow_api" {
  source      = "../network/firewalls/allow_api"
  namespace   = var.namespace
  pod_selector = {
    "app.kubernetes.io/name" = "nginx-gateway-fabric"
  }
}

# ...plus the chart's cert-generator hook Job, which carries none of those labels
# (see "Hook Jobs need their own selector" below).
module "allow_api_cert_generator" {
  source       = "../network/firewalls/allow_api"
  namespace    = var.namespace
  policy_name  = "allow-api-egress-certgen"
  pod_selector = { "job-name" = module.gateway.cert_generator_job_name }
}
```

Kubernetes NetworkPolicies are **additive (union)**: both policies apply to the
NGF controller pods (so they get namespace rules *plus* the API rule), while
the apps only see the namespace-wide policy. The NGF data-plane pods
(`media-private-*`) match neither the API selector nor need the API, so they're
denied too.

> Match the selector to whatever pod label uniquely identifies the API consumer.
> For NGF, `app.kubernetes.io/name = nginx-gateway-fabric` covers the controller
> **deployment only** — see the next section for the chart's hook Job.

## Hook Jobs need their own selector

A Job's pods carry the Job controller's own labels (`job-name`,
`batch.kubernetes.io/job-name`, `controller-uid`) and **nothing the chart
specified for its deployments** — so a `pod_selector` aimed at the controller does
not cover a chart hook, and each hook needs a second call.

That is not hypothetical: NGF's `cert-generator` Job is a `pre-install`/`pre-upgrade`
hook, so an NGF upgrade stalls on it. With media's default-deny egress the hook's pod
got `dial tcp 10.96.0.1:443: i/o timeout`, exhausted its `backoffLimit: 6`, and helm's
`wait` burned the release's full `timeout` (both upgrades waiting on the same deadlock —
2026-09-16). The chart offers no values to label the hook's pods, so the only fix is the
label the Job controller applies anyway:

```hcl
pod_selector = { "job-name" = module.gateway.cert_generator_job_name }
```

`modules/network/gateway` publishes that name as an output (the chart's
`<release>-nginx-gateway-fabric-cert-generator`); don't re-derive it by hand, and give
the policy its own `policy_name` — one NetworkPolicy cannot OR two selectors.

## Rules it renders

- DNS egress to kube-dns (UDP + TCP 53) when `allow_dns` is true (default) —
  in-cluster clients resolve `kubernetes.default.svc` before connecting.
- API egress to `10.96.0.1/32` + the live control-plane endpoint IPs
  (from the `kubernetes` Endpoints object), TCP 6443. Calico evaluates egress
  post-DNAT, so the endpoint-IP entries are what actually authorize a
  connection made to the `kubernetes` service on 443; the `/32` entry is kept
  for parity with `basic_internet`.

It does **not** render same-namespace/internet/kube-network rules — run it
*alongside* a `basic_internet` (or equivalent) policy that provides the
namespace's general egress.

## `api_peer_ips` — when the caller is under a module-level `depends_on`

The control-plane endpoint IPs are read by this module
(`data.kubernetes_endpoints_v1`), *unless* the caller passes `api_peer_ips`.

Pass them whenever this module is reached through a module-level `depends_on`
(e.g. `authentik`, pulled in by `stacks/core/auth.tf` with
`depends_on = [module.cert_man, module.storage, ...]`). A module-level
`depends_on` covers the module's **data sources too**, so any pending change in
the depended-on module defers that read to apply time: the policy then plans a
*guessed* peer-block count (ClusterIP only, 1), the apply reads the real 2, and
the apply aborts with

```
Provider produced inconsistent final plan ...
  .spec[0].egress[1].to: block count changed from 1 to 2
```

Reading the endpoints in the **stack root** and passing them down keeps the peer
list known during plan, so the plan is consistent. `null` (the default) = read
here, which is what every caller without a module-level `depends_on` wants
(`media` does this).

Never "fix" this by hardcoding the control-plane IPs instead: the endpoint entry
is the peer that actually authorizes the API connection post-DNAT, so a
control-plane re-IP would turn into a silent 6443 denial instead of an error.
Invariant + evidence: `.clinedocs/calico-netpols.md`.

## See also

- [`basic_internet` → "Allowing the Kubernetes API"](../basic_internet/README.md#allowing-the-kubernetes-api) — the namespace-wide alternative; read both before choosing.
- [`firewalls/README.md`](../README.md) — decision table and composition notes.
