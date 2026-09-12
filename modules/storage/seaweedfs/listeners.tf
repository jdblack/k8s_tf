# Exposure via the shared private gateway (kube-network): HTTPS listeners for
# admin/master/s3 + HTTPRoutes to the chart's ClusterIP services. TLS is
# terminated at the gateway with linuxguru-ca certs (previously these were
# plain HTTP through the private ingress-nginx, so the scheme changes to
# https:// for these three hostnames).
module "expose_admin" {
  source            = "../../network/gateway/expose"
  name              = "seaweedfs-admin"
  namespace         = var.namespace
  domain            = var.domains[var.visibility]
  hostname          = local.admin_host
  cert_issuer       = local.issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
  backend_name      = "seaweedfs-admin"
  backend_port      = 23646
}

module "expose_master" {
  source            = "../../network/gateway/expose"
  name              = "seaweedfs-master"
  namespace         = var.namespace
  domain            = var.domains[var.visibility]
  hostname          = local.master_host
  cert_issuer       = local.issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
  backend_name      = "seaweedfs-master"
  backend_port      = 9333
}

module "expose_s3" {
  source            = "../../network/gateway/expose"
  name              = "seaweedfs-s3"
  namespace         = var.namespace
  domain            = var.domains[var.visibility]
  hostname          = local.s3_host
  cert_issuer       = local.issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
  backend_name      = "seaweedfs-s3"
  backend_port      = 8333
}

# Migrate the previous listener_set + http_route pairs into the combined
# `expose` module -- pure moves, no destroy/create.
moved {
  from = module.listener_set_admin
  to   = module.expose_admin.module.listener_set
}
moved {
  from = module.http_route_admin
  to   = module.expose_admin.module.http_route[0]
}

moved {
  from = module.listener_set_master
  to   = module.expose_master.module.listener_set
}
moved {
  from = module.http_route_master
  to   = module.expose_master.module.http_route[0]
}

moved {
  from = module.listener_set_s3
  to   = module.expose_s3.module.listener_set
}
moved {
  from = module.http_route_s3
  to   = module.expose_s3.module.http_route[0]
}