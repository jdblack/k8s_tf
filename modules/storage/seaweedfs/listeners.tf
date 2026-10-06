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

  # Public web apps (browser PNA) may not call a private-network host without this
  # on the preflight; SeaweedFS S3 already answers the CORS preflight itself.
  filters = [{
    type = "ResponseHeaderModifier"
    responseHeaderModifier = {
      add = [{
        name  = "Access-Control-Allow-Private-Network"
        value = "true"
      }]
    }
  }]
}

module "expose_lance" {
  source            = "../../network/gateway/expose"
  name              = "seaweedfs-lance"
  namespace         = var.namespace
  domain            = var.domains[var.visibility]
  hostname          = local.lance_host
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
  backend_name      = "seaweedfs-s3"
  backend_port      = 9101
}
