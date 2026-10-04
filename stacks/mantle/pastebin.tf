module "pastebin" {
  source = "../../modules/pastebin"

  # Public app: anyone with a share link can download it from the internet.
  domain      = var.deployment.cluster.domains.public
  cert_issuer = var.deployment.cert_manager.external_issuer

  # authentik stays on the private gateway (LAN/VPN), so only those users can sign in and
  # create shares -- which is what "authorized users" means here.
  oidc_issuer_base = var.deployment.auth.server

  gateway_name = "public"
}
