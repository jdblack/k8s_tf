locals {
  # admin.<release>.<domain> -- previously published by the core seaweedfs module
  # (modules/storage/seaweedfs) and now pointing at the outpost, not the admin
  # Service.
  host = var.admin_host != null ? var.admin_host : "admin.${var.app_name}.${var.domain}"
}

# authentik: proxy provider + application for the admin UI bound to
# var.group_name, plus the outpost + its service-account token
# (see ../../auth/authentik/proxy_app).
module "auth" {
  source = "../../auth/authentik/proxy_app"

  apps = {
    "seaweedfs-admin" = {
      external_host = "https://${local.host}"
      internal_host = "http://${var.admin_service}.${var.namespace}.svc.cluster.local:${var.admin_port}"
      icon          = var.icon
    }
  }

  outpost_name = var.outpost_name
  group_name   = var.group_name
}

# The outpost deployment/service in the SeaweedFS namespace (same namespace as the
# admin service, so the outpost -> admin hop needs no cross-namespace policy).
module "outpost" {
  source = "../../auth/authentik/outpost"

  namespace    = var.namespace
  outpost_name = var.outpost_name
  service_name = var.outpost_service
  core_url     = "http://authentik-server.${var.auth_namespace}.svc.cluster.local:80"
  browser_url  = "https://auth.${var.domain}"
  token        = module.auth.outpost_token
}

# HTTPS listener (admin.<app>.<domain>, private CA) on the shared private gateway
# + HTTPRoute to the OUTPOST -- not the admin service. Reuses the names the core
# module's expose_admin used (ListenerSet "seaweedfs-admin", cert
# cert-admin.<app>.<domain>), so the cert/grants are simply re-owned here.
module "expose" {
  source = "../../network/gateway/expose"

  name              = "${var.app_name}-admin"
  namespace         = var.namespace
  domain            = var.domain
  hostname          = local.host
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
  backend_name      = var.outpost_service
  backend_port      = 9000
}

# The outpost module ships an Egress-only, default-deny policy (kube-auth:9000).
# The SeaweedFS namespace firewall is INGRESS-only, so nothing else opens the
# outpost's egress. Open exactly what it needs: DNS, and the admin service.
# Calico evaluates egress post-DNAT, so the peer is the admin POD, not the
# Service ClusterIP.
module "outpost_egress" {
  source = "../../network/firewalls/policy"

  name      = "${var.app_name}-admin-outpost-egress"
  namespace = var.namespace
  pod_selector = {
    "app.kubernetes.io/name"     = "authentik-outpost"
    "app.kubernetes.io/instance" = var.outpost_name
  }
  policy_types = ["Egress"]

  egress_rules = [
    {
      peers = [{
        namespace_selector = { "kubernetes.io/metadata.name" = var.system_namespace }
        pod_selector       = { "k8s-app" = "kube-dns" }
      }]
      ports = [{ protocol = "UDP", port = 53 }, { protocol = "TCP", port = 53 }]
    },
    {
      peers = [{
        namespace_selector = { "kubernetes.io/metadata.name" = var.namespace }
        pod_selector = {
          "app.kubernetes.io/name"      = var.app_name
          "app.kubernetes.io/component" = "admin"
        }
      }]
      ports = [{ protocol = "TCP", port = var.admin_port }]
    },
  ]
}
