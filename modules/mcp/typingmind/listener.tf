module "expose" {
  source = "../../network/gateway/expose"

  name              = var.name
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace

  # Bearer-token auth: TypingMind's connector settings take a URL and a token, no OIDC.
  backend_name = var.name
  backend_port = var.port
}
