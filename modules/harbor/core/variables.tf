
variable namespace {  }
variable name      { default     = "harbor" }
variable domain    { type = string }
variable certca    { type = string } 
variable auth_secret { }
variable ssl_ca {}
variable ssl_ca_namespace {}
variable oidc_id  { default = "harbor" }
variable keycloak_endpoint {}

locals {
  fqdn = "${var.name}.${var.domain}"
  url = "https://${local.fqdn}"
  oidc_callback = "${local.url}/c/oidc/callback"
}
