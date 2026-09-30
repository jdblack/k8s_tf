module "vaultwarden" {
  source = "../../modules/vaultwarden"

  namespace   = "vaultwarden"
  domain      = var.deployment.cluster.domains.private
  cert_issuer = var.deployment.cert_manager.external_issuer

  image_tag = "1.37.3"

  signups_allowed = true
}
