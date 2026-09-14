# `proxy_app` — authentik proxy providers for apps that speak no OIDC

Creates the authentik side of the **proxy outpost** pattern: a proxy provider +
application per app, one access group, and the outpost that fronts them. Pairs
with [`../outpost`](../outpost/README.md), which runs the matching Kubernetes
Deployment/Service in the namespace being protected.

Used by `modules/media` (the *arr apps + qbittorrent web UI),
`modules/network/whisker`, and `modules/storage/seaweedfs_admin`.

## Why a proxy outpost instead of OIDC

The apps have no OIDC support, and their clients are browsers. So the gateway
routes the public hostname to the **outpost** (not to the app), the outpost
authenticates the user against authentik and injects `X-authentik-*` headers,
then reverse-proxies to the app's in-cluster Service.

```
browser -> <app>.<domain> (TLS at the gateway)
         -> outpost :9000   (no session = 302 to the authentik login)
         -> <app>:<port>
```

The app's own login must then be neutralised, or the user gets prompted twice:
the *arr apps run `AuthenticationMethod = External`; qBittorrent instead
whitelists the pod CIDR. Both are one-time, hand-run steps — see the main
README.

## What it creates

| Resource | Detail |
|---|---|
| `authentik_provider_proxy` per `var.apps` entry | `mode = proxy`, `external_host` (the URL the gateway serves), `internal_host` (the app's in-cluster Service) |
| `authentik_application` per entry | slug = the map key, launch URL = `external_host`, tile icon from `icon` |
| `authentik_group` | `var.group_name` — the **only** access control |
| `authentik_policy_binding` | binds each application to that group (`order = 0`) |
| `authentik_outpost` | one proxy outpost for all the apps (`var.outpost_name`), `protocol_providers` = every provider created here |
| `authentik_token` | a non-expiring API token for the outpost's auto-created service account (`ak-outpost-<uuid>`), exposed as the `outpost_token` output |

## Inputs / outputs

- `apps` — `map(object({ external_host, internal_host, icon }))`; the key is the
  slug. Add an entry and re-apply to publish another app through the same
  outpost.
- `outpost_name` (`media-proxy`), `group_name` (`media`).
- Outputs `outpost_name`, `outpost_token` (sensitive), `apps`.

## Access control

Membership in `var.group_name` is the entire gate — **no bindings, no access**
for anyone. Terraform owns the group; people are added by hand in the authentik
UI (the repo-wide convention). A from-scratch rebuild therefore needs the
members re-added.

The group resource once carried a `count`; there is a `moved` block keeping the
existing indexed instances (and their hand-managed memberships) intact.
