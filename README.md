# Kubernetes Terraform

This deployment is split into three stacks due to certain terraform limitations
involving providers.  Terraform is unable to create a provider for a service
that it has just built.  For example, consider Keycloak, which is created with
the Helm provider, but then configured with the Keycloak provider. The
Keycloak provider can not exist until after the helm provider has finished.

To deal with this, we have three stack directories, each of which needs
to be deployed independently with `terraform apply`.

## Layout

```
stacks/
├── core/     # infrastructure foundation (network, storage, certs, platform services)
├── mantle/   # workload layer (media, harbor/argo config, blender)
└── apps/     # ArgoCD app-of-apps (ai, websites)
```

## Deployment Order

1. **`stacks/core/`** — deploys the base infrastructure: network, storage,
   cert-manager, auth, and devops platform services (Harbor, ArgoCD).
2. **`stacks/mantle/`** — deploys workloads on top: media stack, harbor/argo
   configuration, and blender.
3. **`stacks/apps/`** — deploys applications via ArgoCD app-of-apps.

Each stack uses a Kubernetes secret backend with a distinct `secret_suffix`
(`core`, `mantle`, `deployment`) to keep state separate.

### Authentik in front of the media apps (sonarr / radarr / prowlarr / bazarr /
qbittorrent web UI)

None of these speak OIDC, so authentik fronts them as a **proxy outpost**
(`modules/auth/authentik/proxy_app` + `modules/auth/authentik/outpost`), not
SSO. Traffic flow:

```
browser -> sonarr.vn.linuxguru.net (media-private gateway, TLS)
         -> authentik outpost (media namespace, :9000)   <- no session = 302 to auth.vn.linuxguru.net
         -> sonarr:80 (X-authentik-* headers injected)
```

- `modules/media/auth.tf` wires it up: per-app authentik proxy providers +
  applications + the shared `media-proxy` outpost, all bound to the **`media`**
  group. The *arr apps' chart-generated HTTPRoutes are disabled and each app
  module renders its own route to the outpost (`route.tf`, `auth_backend`
  variable); the port differs per app (arr charts `:80`, qbittorrent web UI
  `:8080`). qbittorrent is hand-rolled (no chart) so it already owned its route
  — it now uses the same `listener_set` + `http_route` modules and arguments as
  the arr apps.
- **Access control** = membership in the `media` group in authentik, managed by
  hand in the UI (TF never touches users — same as harbor/argo). Nobody can see
  the apps until you add them.
- Adding another protected app: add it to the `auth_apps` map in
  `modules/media/auth.tf` and instantiate its module (with `auth_backend`) in
  `modules/media/arr_stack.tf`.
- **qbittorrent is a special case — only the web UI is fronted:**
  - The **torrent port (21010) is deliberately NOT behind the outpost** — peers
    can't log in. It lives on its own `qbittorrent-torrent` LoadBalancer Service,
    **pinned to the MetalLB IP the home router port-forwards** (`192.168.0.105`,
    via `qbittorrent_torrent_lb_ip` in `stacks/mantle/terraform.tfvars`) so the
    split from the old combined Service can't reassign it. If the pinned IP ends
    up `Pending` on apply, re-apply once the old Service releases it.
  - The **web UI is a ClusterIP Service** (`qbittorrent:8080`), so it is only
    reachable through the gateway/outpost — no LAN-side IP that bypasses
    authentik.
  - The *arr apps must point their qBittorrent **download client at `qbittorrent`
    port `8080`** (the in-cluster Service). Using the LB IP, or the
    authenticated `qbittorrent.<domain>` hostname, breaks: the latter hits
    authentik and gets a login redirect, not the API.
- **One-time per-app setup:** sonarr/radarr/prowlarr run with
  `AuthenticationMethod = External` (config.xml, set once through their own API)
  so there's no second login prompt. On a from-scratch rebuild the app config
  PVCs start fresh and this must be redone:
  `kubectl -n media exec deploy/<app> -- sh -c 'KEY=$(grep -o "<ApiKey>[^<]*" /config/config.xml | sed "s/<ApiKey>//" | head -1); CFG=$(curl -s -H "X-Api-Key: $KEY" http://localhost:<port>/api/v3/config/host); curl -s -X PUT -H "X-Api-Key: $KEY" -H "Content-Type: application/json" -d "$(echo "$CFG" | jq ".authenticationMethod=\"external\"")" http://localhost:<port>/api/v3/config/host'`
  (ports: sonarr 8989, radarr 7878, prowlarr 9696/`api/v1`).
  qBittorrent has no trusted-header auth, so it can't use `External`. Instead
  it **bypasses its own login for the pod CIDR** (Calico `10.244.0.0/16`): the
  outpost proxies from a pod, so there's no second prompt. Set once in
  `/config/qBittorrent/qBittorrent.conf` under `[Preferences]`:
  `WebUI\AuthSubnetWhitelistEnabled=true` and
  `WebUI\AuthSubnetWhitelist=10.244.0.0/16` (or via *WebUI → Bypass
  authentication for clients in whitelisted IP subnets*). Editing the file while
  qBittorrent runs is **not** enough — it rewrites the file from memory on a
  graceful exit — so patch it and then hard-kill the pod so the new one reads
  the patch: `kubectl -n media delete pod -l app.kubernetes.io/name=qbittorrent
  --grace-period=0 --force`. (`WebUI\ServerDomains=*` is already set, so
  host-header validation doesn't block the proxy.) Because the web UI Service is
  ClusterIP-only, this whitelist doesn't weaken external exposure.

### Gateway API (NGINX Gateway Fabric)

- `stacks/core` installs the **Gateway API CRDs** (`gateway.networking.k8s.io/*`)
  via a `terraform_data` bootstrap step in `modules/network/api_gateway_config.tf`
  (runs `kubectl`, idempotent, requires `kubectl` on the machine running tofu).
  The NGF Helm chart installs its own CRDs (`gateway.nginx.org/*`) automatically
  from its `crds/` directory — no manual step needed for those.
- **Rebuild order matters:** `stacks/core` must be applied before
  `stacks/mantle`, because the media module's HTTPRoutes
  (`kubernetes_manifest`) need the HTTPRoute CRD to exist at plan time. On a
  brand-new cluster, apply `stacks/core` first (or run
  `tofu apply -target=module.network.terraform_data.gateway_api_crds` once) so
  the CRDs exist before any stack plans Gateway API resources.
- **The gateway module is generic shared infrastructure** (`modules/network/gateway`):
  an NGF control plane + GatewayClass, plus a Gateway whose only built-in
  listener is `:80` HTTP — plain-HTTP requests are dropped (404), never
  redirected or served; HTTPS is the only way in via app-declared
  `ListenerSet`s. It knows nothing about individual apps. Callers instantiate
  it per namespace (the media module creates the `media-private` instance).
- **Shared `public` / `private` gateways** replace the old ingress-nginx
  controllers (`modules/network/gateways.tf`, removed `ingress.tf`). They live
  in `kube-network`, watch all namespaces, allow ListenerSets from any
  namespace, and their data-plane Services are pinned to the IPs the old
  controllers held (192.168.0.101 public / 192.168.0.100 private, wired via
  `gateway_ips` in `stacks/core` from tfvars `network_ingress.*_ip`).
- **Each app owns its exposure** in its own module (`modules/<mod>/listener.tf`)
  via the [`gateway/expose`](modules/network/gateway/expose/README.md)
  submodule: one call renders the app's `ListenerSet` (its HTTPS listener on the
  public/private/media gateway) annotated with the cert-manager issuer so the
  `cert-<host>` secret is auto-provisioned (private CA or letsencrypt), plus an
  `HTTPRoute` (host -> service). Charts that render their own route
  (harbor/authentik/argo-cd) omit `backend_name` and get the listener only.
  Apps behind the authentik outpost (sonarr/radarr/prowlarr/bazarr, plus the
  qbittorrent web UI) point the route at the outpost service instead
  (`route_name = "<app>-auth"`; see above). `expose` auto-creates the
  cross-namespace `ReferenceGrant` when the gateway lives in another namespace.
  Certs and secrets live with the services that use them. Rebuild-from-scratch
  is fully `tofu`-driven.
