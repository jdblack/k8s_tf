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
```

Kubernetes NetworkPolicies are **additive (union)**: both policies apply to the
NGF controller pods (so they get namespace rules *plus* the API rule), while
the apps only see the namespace-wide policy. The NGF data-plane pods
(`media-private-*`) match neither the API selector nor need the API, so they're
denied too.

> Match the selector to whatever pod label uniquely identifies the API consumer.
> For NGF, `app.kubernetes.io/name = nginx-gateway-fabric` covers the controller
> deployment and the chart's cert-generator job.

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

## See also

- [`basic_internet` → "Allowing the Kubernetes API"](../basic_internet/README.md#allowing-the-kubernetes-api) — the namespace-wide alternative; read both before choosing.
- [`firewalls/README.md`](../README.md) — decision table and composition notes.
