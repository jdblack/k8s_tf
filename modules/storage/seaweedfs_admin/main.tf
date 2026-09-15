locals {
  # admin.<release>.<domain>; the outpost owns this host.
  host = var.admin_host != null ? var.admin_host : "admin.${var.app_name}.${var.domain}"
}

# authentik: proxy provider + application for the admin UI, plus the outpost and its
# service-account token.
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

# Co-located with the admin Service, so that hop needs no cross-namespace policy.
module "outpost" {
  source = "../../auth/authentik/outpost"

  namespace    = var.namespace
  outpost_name = var.outpost_name
  service_name = var.outpost_service
  core_url     = "http://authentik-server.${var.auth_namespace}.svc.cluster.local:80"
  browser_url  = "https://auth.${var.domain}"
  token        = module.auth.outpost_token
}

# Listener + HTTPRoute to the OUTPOST, not the admin Service. The names carry those of
# core's retired expose_admin, so the cert and grants are re-owned here.
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

# The outpost module's policy is egress default-deny and the SeaweedFS namespace
# firewall is ingress-only, so nothing else opens this egress. Peers are post-DNAT
# pods, not Service IPs.
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
