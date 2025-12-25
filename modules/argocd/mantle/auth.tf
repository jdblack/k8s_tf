
module auth {
  namespace = var.namespace
  domain = var.domain
  oauth2_host = "auth.vn.linuxguru.net"
  ca_cert_cm = var.ca_cert_cm
  source = "../../auth/authentik/oidc_provider"
}
