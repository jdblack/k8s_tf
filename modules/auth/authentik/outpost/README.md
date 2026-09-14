# `outpost` — the authentik proxy outpost, as a Terraform-owned workload

Runs the outpost that [`../proxy_app`](../proxy_app/README.md) registered: a
Deployment + ClusterIP Service (and the Secret holding its API token) **in the
namespace being protected**.

Needed because authentik chart 2025.10.x no longer embeds proxy outposts
(managed/embedded outposts are disabled in this release). Terraform owning the
pods is also what keeps a from-scratch rebuild `tofu`-driven, and it means the
protected namespace's egress firewall applies to the outpost like any other
workload.

## What it creates

| Resource | Detail |
|---|---|
| Secret `<service_name>-api` | `AUTHENTIK_HOST` (`core_url`), `AUTHENTIK_HOST_BROWSER` (`browser_url`), `AUTHENTIK_TOKEN` |
| Deployment `<service_name>` | one replica, image `var.image:var.image_tag`, ports `9000` (http) / `9443` (https), labels `app.kubernetes.io/name=authentik-outpost` + `instance=<outpost_name>` |
| Service `<service_name>` | ClusterIP, ports 9000 + 9443 — **this is what the app's HTTPRoute points at** |
| netpol `authentik-outpost-core` | egress to authentik core only (see below) |

## The two URLs, and why both are required

- `core_url` — in-cluster API/websocket endpoint
  (`http://authentik-server.kube-auth...:80`). Never seen by a browser, so plain
  HTTP is fine.
- `browser_url` — the public authentik URL (`https://auth.<domain>`). Used in
  browser-facing redirects during the OAuth dance. **If it is empty the outpost
  falls back to `core_url`, which leaks the internal service name into
  redirects** — always pass the public host.

## The egress carve-out

The outpost's own policy is **egress-only and default-deny**: it may reach
authentik core's pods on **port 9000 post-DNAT** (the Service is
`authentik-server:80`, but Calico evaluates egress after DNAT, so the allow has
to name the pod's real port). It is rendered with
[`../../../../network/firewalls/policy`](../../../network/firewalls/policy/README.md)
so it matches the rest of the firewall library.

In `media` that is additive to the namespace-wide `basic_internet` posture,
which supplies same-namespace + DNS. In `calico-system` (whisker) and
`kube-storage` (seaweedfs admin) there is no namespace-wide egress policy to
lean on, so the caller adds a second pod-scoped policy for DNS + the app.

## Inputs

`namespace`, `outpost_name` (`media-proxy`), `service_name`
(`authentik-outpost`), `core_url`, `browser_url`, `token` (the `proxy_app`
output), `core_namespace` (`kube-auth`), `image` / `image_tag`
(`ghcr.io/goauthentik/proxy:2025.10.3`).
