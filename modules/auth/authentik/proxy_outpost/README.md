# `proxy_outpost` — authentik proxy providers **and** the outpost that fronts them

The whole proxy-outpost pattern in one module: the authentik side (proxy provider +
application per app, one access group, the outpost, its non-expiring API token) and the
Kubernetes side (Secret + Deployment + ClusterIP Service + egress carve-out) in the
namespace being protected.

It was two modules (`proxy_app` + `outpost`) until they merged: the halves are always
called as a pair, share `outpost_name`/`service_name`, and the API token has no business
crossing a module boundary.

Used by `modules/media` (the *arr apps + qbittorrent web UI),
`modules/network/whisker`, and `modules/storage/seaweedfs_admin`.

## Why a proxy outpost instead of OIDC

The apps have no OIDC support, and their clients are browsers. So the gateway routes the
public hostname to the **outpost** (not to the app), the outpost authenticates the user
against authentik and injects `X-authentik-*` headers, then reverse-proxies to the app's
in-cluster Service.

```
browser -> <app>.<domain> (TLS at the gateway)
         -> <service_name>:9000 (no session = 302 to the authentik login)
         -> <app>:<port>
```

The app's own login must then be neutralised, or the user gets prompted twice: the *arr
apps run `AuthenticationMethod = External`; qBittorrent instead whitelists the pod CIDR.
Both are one-time, hand-run steps — see the main README.

Terraform owns the pods because authentik chart 2025.10.x no longer embeds proxy outposts;
that also makes a from-scratch rebuild `tofu`-driven.

## What it creates

| Resource | Detail |
|---|---|
| `authentik_provider_proxy` per `var.apps` entry | `mode = proxy`, `external_host` (the URL the gateway serves), `internal_host` (the app's in-cluster Service) |
| `authentik_application` per entry | slug = the map key, launch URL = `external_host`, tile icon from `icon` |
| `authentik_group` | `var.group_name` — the **only** access control |
| `authentik_policy_binding` | binds each application to that group (`order = 0`) |
| `authentik_outpost` | one proxy outpost for all the apps (`var.outpost_name`), `protocol_providers` = every provider created here |
| `authentik_token` | a non-expiring API token for the outpost's auto-created service account (`ak-outpost-<uuid>`) |
| Secret `<service_name>-api` | `AUTHENTIK_HOST` (`core_url`), `AUTHENTIK_HOST_BROWSER` (`browser_url`), `AUTHENTIK_TOKEN` |
| Deployment `<service_name>` | one replica, image `var.image:var.image_tag`, ports `9000` (http) / `9443` (https), labels `app.kubernetes.io/name=authentik-outpost` + `instance=<outpost_name>` |
| Service `<service_name>` | ClusterIP, ports 9000 + 9443 — **this is what the app's HTTPRoute points at** |

## Inputs / outputs

- `apps` — `map(object({ external_host, internal_host, icon }))`; the key is the slug. Add
  an entry and re-apply to publish another app through the same outpost.
- `namespace`, `service_name` (`authentik-outpost`), `outpost_name` (`media-proxy`),
  `group_name` (`media`), `domain`, `core_namespace` (`kube-auth`), `image`/`image_tag`.
- Outputs `outpost_name`, `apps`. The API token is **not** an output — it goes straight
  into the Secret in this module.

## The two URLs, and why the module derives them

- `core_url` — in-cluster API/websocket endpoint
  (`http://authentik-server.<core_namespace>...:80`). Never seen by a browser, so plain
  HTTP is fine.
- `browser_url` — the public authentik URL (`https://auth.<domain>`, overridable with
  `auth_fqdn`). Used in browser-facing redirects during the OAuth dance. **If it were
  empty the outpost would fall back to `core_url`, which leaks the internal service name
  into redirects.**

Both are locals here rather than caller inputs: three callers used to pass the same two
strings, and the literal only ever needs updating in one place. `auth.<domain>` mirrors
core's `local.fqdn` (pinned in `stacks/core/auth.tf`).

## Egress

The outpost is a plain pod with **no network policy** around it: the module used to render
an egress default-deny plus a carve-out to authentik core on **port 9000 post-DNAT** (the
Service is `authentik-server:80`, but Calico evaluates egress after DNAT, so a policy has to
name the pod's real port). That whole layer — and with it the `firewalls/policy` renderer
these calls used — was deleted 2026-09-16; the note survives only because a rebuild that
reintroduces policy has to re-derive the port from DNAT, not from the Service.

## Access control

Membership in `var.group_name` is the entire gate — **no bindings, no access** for anyone.
Terraform owns the group; people are added by hand in the authentik UI (the repo-wide
convention). A from-scratch rebuild therefore needs the members re-added.

The group resource once carried a `count`; it does not any more, and its address must
never be re-indexed — changing it destroys and recreates the group, which drops the
members added by hand in the UI.
