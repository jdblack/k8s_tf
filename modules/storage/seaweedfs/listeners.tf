# Exposure via the shared private gateway (kube-network): HTTPS listeners for
# admin/master/s3 + HTTPRoutes to the chart's ClusterIP services. TLS is
# terminated at the gateway with linuxguru-ca certs (previously these were
# plain HTTP through the private ingress-nginx, so the scheme changes to
# https:// for these three hostnames).
module "listener_set_admin" {
  source            = "../../network/gateway/listener_set"
  name              = "seaweedfs-admin"
  namespace         = var.namespace
  domain            = var.domains[var.visibility]
  hostname          = local.admin_host
  cert_issuer       = local.issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
}

module "listener_set_master" {
  source            = "../../network/gateway/listener_set"
  name              = "seaweedfs-master"
  namespace         = var.namespace
  domain            = var.domains[var.visibility]
  hostname          = local.master_host
  cert_issuer       = local.issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
}

module "listener_set_s3" {
  source            = "../../network/gateway/listener_set"
  name              = "seaweedfs-s3"
  namespace         = var.namespace
  domain            = var.domains[var.visibility]
  hostname          = local.s3_host
  cert_issuer       = local.issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
}

module "http_route_admin" {
  source       = "../../network/gateway/http_route"
  name         = "seaweedfs-admin"
  namespace    = var.namespace
  domain       = var.domains[var.visibility]
  hostname     = local.admin_host
  backend_name = "seaweedfs-admin"
  backend_port = 23646
}

module "http_route_master" {
  source       = "../../network/gateway/http_route"
  name         = "seaweedfs-master"
  namespace    = var.namespace
  domain       = var.domains[var.visibility]
  hostname     = local.master_host
  backend_name = "seaweedfs-master"
  backend_port = 9333
}

module "http_route_s3" {
  source       = "../../network/gateway/http_route"
  name         = "seaweedfs-s3"
  namespace    = var.namespace
  domain       = var.domains[var.visibility]
  hostname     = local.s3_host
  backend_name = "seaweedfs-s3"
  backend_port = 8333
}
