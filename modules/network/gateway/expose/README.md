# `expose` — publish an app through a gateway in one call

An HTTPS `ListenerSet` (with its cert and the cross-namespace
`ReferenceGrant`s) plus, optionally, an `HTTPRoute` to the app's backend. This
is just the common pairing of [`../listener_set`](../listener_set/README.md) +
[`../http_route`](../http_route/README.md) behind one call — they were always
used together — so an app's exposure is a single block.

```hcl
module "expose" {
  source            = "../../network/gateway/expose"
  name              = var.name
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer          # linuxguru-ca / letsencrypt
  gateway_name      = var.gateway_name         # media-private / private / public
  gateway_namespace = var.gateway_namespace

  # optional HTTPRoute:
  backend_name = var.auth_backend              # omit -> listener only
  backend_port = 9000
  route_name   = "${var.name}-auth"            # defaults to <name>
}
```

- **`backend_name` empty = listener only.** Charts that render their own
  `HTTPRoute` (harbor, authentik, argo-cd) leave it unset; they still get the
  listener, its cert, and the grants.
- **The route hostname is the listener FQDN** (`<name>.<domain>`, or
  `hostname` if set) — *not* the route name, so a `<name>-auth` route still
  serves the unprefixed host.
- `hostname` overrides for sub-subdomains (e.g. `admin.seaweedfs.<domain>`).

## Migration

Because `expose` wraps the two modules unchanged, migrating a caller is a
couple of `moved` blocks rather than a resource move storm:

```hcl
moved { from = module.listener_set, to = module.expose.module.listener_set }
moved { from = module.http_route,   to = module.expose.module.http_route[0] }
```

(one `moved` for listener-only callers). No destroy/create.