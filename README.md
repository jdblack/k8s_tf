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
- **Each app owns its exposure** in its own module
  (`modules/<mod>/listener.tf` or `route.tf`): a `ListenerSet` (its HTTPS
  listener on the public/private/media gateway) annotated with the cert-manager
  issuer so the `cert-<host>` secret is auto-provisioned (private CA or
  letsencrypt), plus an `HTTPRoute` (host -> service). Charts that support it
  configure the route via helm values (`route.main`, e.g. sonarr/radarr);
  others use `kubernetes_manifest` (the qbittorrent/threadfin pattern). The
  `listener_set` submodule auto-creates the cross-namespace `ReferenceGrant`
  when the gateway lives in another namespace. Certs and secrets live with the
  services that use them. Rebuild-from-scratch is fully `tofu`-driven.
