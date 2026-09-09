# `listener_set` — app-owned HTTPS listener on a Gateway

Declares an HTTPS (or plain-HTTP) `ListenerSet` for one hostname on a gateway
instance, and gets cert-manager to provision the certificate for it.

## What it creates

- **`ListenerSet`** — one HTTPS listener (default port 443) for hostname
  `<name>.<domain>` (or an explicit `hostname` override for sub-subdomains like
  `admin.seaweedfs.<domain>`). When `cert_issuer` is set, the listener carries
  the `cert-manager.io/cluster-issuer` annotation so the gateway-shim
  auto-provisions a `cert-<hostname>` secret in **this** namespace.
- **`ReferenceGrant`s** — when the gateway lives in another namespace
  (`gateway_namespace != namespace`), the grants that allow the cross-namespace
  `ListenerSet` → Gateway attachment, and a second one covering charts that
  attach their own `HTTPRoute` directly to the Gateway (e.g. harbor's
  `expose.type = "route"`).

`allowedRoutes.from = All` on the listener is intentional: charts in other
namespaces render HTTPRoutes against the gateway by hostname matching, and the
hostname scoping is what keeps them app-isolated.

## Usage

```hcl
module "listener_set" {
  source            = "../network/gateway/listener_set"
  name              = "sonarr"                 # -> sonarr.<domain>
  namespace         = var.namespace            # app namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = "media-private"
  gateway_namespace = var.namespace
}
```

Combine with the matching [`http_route`](../http_route/README.md) so traffic
for the hostname actually reaches a Service.
