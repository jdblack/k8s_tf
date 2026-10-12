module "forgejo" {
  source = "../../modules/forgejo"

  domain      = var.deployment.cluster.domains.private
  cert_issuer = var.deployment.cert_manager.external_issuer

  # authentik stays on the private gateway; OIDC discovery and the token exchange go there.
  oidc_issuer_base = var.deployment.auth.server
  host_network     = var.deployment.network.host_cidr
}
