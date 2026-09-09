# `http_route` — app-owned hostname → Service route

Creates a single-hostname `HTTPRoute` that forwards HTTPS traffic for
`<name>.<domain>` (or an explicit `hostname`) to one backend Service. Adds the
`external-dns.alpha.kubernetes.io/hostname` annotation so the internal Bind zone
stays pointed at the gateway.

## Route attachment

The route `parentRef`s the app's `ListenerSet` by default
(`parent_kind = "ListenerSet"`, name = the route name). To attach directly to a
Gateway instead — the pattern used by charts that render their own routes — set
`parent_kind = "Gateway"` plus `parent_name` / `parent_namespace`.

```hcl
module "http_route" {
  source       = "../network/gateway/http_route"
  name         = "sonarr"
  namespace    = var.namespace
  domain       = var.domain
  backend_name = "sonarr"
  backend_port = 8989
}
```

Used together with [`listener_set`](../listener_set/README.md); the cert it
provisions and this route share the same hostname, so they must agree.
