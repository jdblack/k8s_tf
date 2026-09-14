# Exposure via the shared private gateway (kube-network): HTTPS listeners for
# master/s3 + HTTPRoutes to the chart's ClusterIP services. TLS terminates at the
# gateway with linuxguru-ca certs.
#
# The ADMIN UI is deliberately NOT published here: it is fronted by an authentik
# proxy outpost, which must live in the mantle stack (only mantle has the
# authentik provider -- see modules/storage/seaweedfs_admin).
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

# Migrate the previous listener_set + http_route pairs into the combined `expose`
# module -- pure moves, no destroy/create. The old admin pair is gone with
# expose_admin: the admin host is now owned by modules/storage/seaweedfs_admin
# (mantle), so core destroys its ListenerSet / route / grants and mantle
# re-creates them behind the authentik outpost.
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