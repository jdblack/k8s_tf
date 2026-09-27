module "immich" {
  source = "./immich"

  namespace         = var.namespace
  domain            = var.domain
  library_pvc       = var.photos_pvc
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace

  # Same group the outpost gates the rest of the stack with.
  oidc_group_id = module.auth.group_id
}
