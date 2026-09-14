# `media` — the arr stack, its gateway, and its authentik outpost

One namespace (`media`) holding sonarr / radarr / prowlarr / bazarr (helm charts,
each in its own submodule), plex, a hand-rolled qbittorrent, the namespace-local
**`media-private` NGF gateway** (`api_gateway.tf`, `.106` from the MetalLB pool —
unlike the shared gateways it is *not* IP-pinned in code), the shared authentik
outpost, and the namespace netpols (`security.tf`).

Non-HTTP ingress: plex also listens on its own LoadBalancer, and qBittorrent
peers connect to `qbittorrent-torrent` on `192.168.0.105:21010` — never through
authentik.

## Authentik in front of the apps (arr + qbittorrent web UI)

None of these speak OIDC, so authentik fronts them as a **proxy outpost**
(`modules/auth/authentik/proxy_app` + `modules/auth/authentik/outpost`):

```
browser -> sonarr.vn.linuxguru.net (media-private gateway, TLS)
         -> authentik outpost (media namespace, :9000)   <- no session = 302 to auth.vn.linuxguru.net
         -> sonarr:80 (X-authentik-* headers injected)
```

- `auth.tf` wires it up: per-app authentik proxy providers + applications + the
  shared `media-proxy` outpost, all bound to the **`media`** group. The *arr
  apps' chart-generated HTTPRoutes are disabled and each app module renders its
  own route to the outpost instead (`listener.tf`, via the `auth_backend`
  variable); the port differs per app (arr charts `:80`, qbittorrent web UI
  `:8080`). qbittorrent is hand-rolled (no chart) so it already owned its route —
  it uses the same `gateway/expose` call and arguments as the arr apps.
- **Access control** = membership in the `media` group in authentik, managed by
  hand in the UI (TF never touches users — same as harbor/argo). Nobody can see
  the apps until you add them.
- Adding another protected app: add it to the `auth_apps` map in `auth.tf` and
  instantiate its module (with `auth_backend`) in `arr_stack.tf`.

## qbittorrent is a special case — only the web UI is fronted

- The **torrent port (21010) is deliberately NOT behind the outpost** — peers
  can't log in. It lives on its own `qbittorrent-torrent` LoadBalancer Service,
  **pinned to the MetalLB IP the home router port-forwards** (`192.168.0.105`,
  via `qbittorrent_torrent_lb_ip` in `stacks/mantle/terraform.tfvars`) so the
  split from the old combined Service can't reassign it. If the pinned IP ends
  up `Pending` on apply, re-apply once the old Service releases it.
- The **web UI is a ClusterIP Service** (`qbittorrent:8080`), so it is only
  reachable through the gateway/outpost — no LAN-side IP that bypasses authentik.
- The *arr apps must point their qBittorrent **download client at `qbittorrent`
  port `8080`** (the in-cluster Service). Using the LB IP, or the authenticated
  `qbittorrent.<domain>` hostname, breaks: the latter hits authentik and gets a
  login redirect, not the API.

## One-time per-app setup (not in Terraform, redone after a rebuild)

sonarr/radarr/prowlarr run with `AuthenticationMethod = External` (config.xml,
set once through their own API) so there's no second login prompt. On a
from-scratch rebuild the app config PVCs start fresh and this must be redone:

```sh
kubectl -n media exec deploy/<app> -- sh -c 'KEY=$(grep -o "<ApiKey>[^<]*" /config/config.xml | sed "s/<ApiKey>//" | head -1); CFG=$(curl -s -H "X-Api-Key: $KEY" http://localhost:<port>/api/v3/config/host); curl -s -X PUT -H "X-Api-Key: $KEY" -H "Content-Type: application/json" -d "$(echo "$CFG" | jq ".authenticationMethod=\"external\"")" http://localhost:<port>/api/v3/config/host'
```

Ports: sonarr 8989, radarr 7878, prowlarr 9696 (`api/v1`).

qBittorrent has no trusted-header auth, so it can't use `External`. Instead it
**bypasses its own login for the pod CIDR** (Calico `10.244.0.0/16`): the outpost
proxies from a pod, so there's no second prompt. Set once in
`/config/qBittorrent/qBittorrent.conf` under `[Preferences]`:
`WebUI\AuthSubnetWhitelistEnabled=true` and
`WebUI\AuthSubnetWhitelist=10.244.0.0/16`. Editing the file while qBittorrent
runs is **not** enough — it rewrites the file from memory on a graceful exit — so
patch it and then hard-kill the pod so the new one reads the patch:

```sh
kubectl -n media delete pod -l app.kubernetes.io/name=qbittorrent --grace-period=0 --force
```

(`WebUI\ServerDomains=*` is already set, so host-header validation doesn't block
the proxy. The web UI Service being ClusterIP-only is why this whitelist doesn't
weaken external exposure.)

## Netpol posture (`security.tf`)

- Egress: namespace-wide `basic_internet` with `allow_to_k8sapi = false`, plus a
  **pod-scoped** `allow_api` for the NGF control plane only — the canonical
  "prefer `allow_api` over `allow_to_k8sapi`" example.
- Ingress: `limited_ingress` = same-namespace + `kube-network-vpn` (WireGuard
  clients land on the wg-server pod) + `0.0.0.0/0 minus the cluster CIDRs` (the
  LoadBalancer apps), plus a pod-scoped `limited_ingress` for plex so
  `kube-network` reaches plex only. This is why the arr ClusterIPs can't be hit
  directly, bypassing the outpost.
- Locked down 2026-09-12; the other namespaces are not — see `TODO.md`.
