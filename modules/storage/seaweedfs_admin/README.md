# `seaweedfs_admin` — SeaweedFS admin UI, authentik-protected

Publishes the SeaweedFS **admin UI** (`weed admin`) at `admin.seaweedfs.<domain>`
the same way the media apps / whisker are published — HTTPS on the shared
**private** gateway, fronted by an **authentik proxy outpost** so access is
SSO-gated by group membership — instead of the raw route to `seaweedfs-admin`
that used to sit there wide open.

## What it renders

| Piece | From | Purpose |
|---|---|---|
| authentik proxy provider + application + outpost + token | `auth/authentik/proxy_app` | SSO gate; app bound to `group_name` |
| outpost Deployment/Service (`seaweedfs-admin-auth`, :9000) in `namespace` | `auth/authentik/outpost` | authenticates, then proxies to the admin UI |
| ListenerSet (HTTPS, cert) + HTTPRoute → the **outpost** | `gateway/expose` | `admin.<app>.<domain>` on the private gateway |
| pod-scoped egress policy on the outpost pods | `firewalls/policy` | DNS + `seaweedfs-admin:<port>` only |

## Why it lives in the mantle stack

authentik is **created by** the core stack, so a provider pointed at its API can
only exist in a later apply — `stacks/mantle` is the only stack with the
authentik provider configured. The SeaweedFS release and its Services remain
core's (`stacks/core/storage.tf`); this module only adds the auth layer and is
now what owns the `admin.seaweedfs.<domain>` listener/route. `stacks/core` must
be applied first on a fresh build (it drops the old direct admin exposure) so
the ListenerSet isn't double-owned.

## Notes

- **No app-level login**: `weed admin` runs with auth disabled and binds
  `0.0.0.0` via `-allowInsecureBind` (see `modules/storage/seaweedfs/locals.tf`),
  so authentik's outpost is the *only* gate. The flip side: anything that can
  reach the pod on 23646 — kube-storage, kube-network, monitoring — gets an
  unauthenticated admin API, bypassing the outpost. Only the gateway path is
  SSO-gated.
- **The outpost is co-located** in the SeaweedFS namespace, so the outpost →
  admin hop is same-namespace: the namespace's ingress firewall already admits
  it (`kube-storage` is in its own guest list) and the gateway (`kube-network`)
  can reach the outpost the same way.
- **Access is the `storage` group**: this module creates it (via `proxy_app`) and
  binds the app to it — there is no shared-group lookup. Add people in the
  authentik UI; any future storage app joins this same group.
- **Icon**: dashboard-icons (the set the media apps use) has no seaweedfs tile, so
  `icon` defaults to the **SeaweedFS** mark from the selfh.st icon set via
  jsDelivr. Override `var.icon` to change it; `null` leaves the tile iconless.
