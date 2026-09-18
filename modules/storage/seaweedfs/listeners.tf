module "expose_master" {
  source            = "../../network/gateway/expose"
  name              = "seaweedfs-master"
  namespace         = var.namespace
  domain            = var.domains[var.visibility]
  hostname          = local.master_host
  cert_issuer       = var.cert_issuer
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
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
  backend_name      = "seaweedfs-s3"
  backend_port      = 8333
}
