
variable domain {}
variable name { default="harbor" }
variable oidc_name { default = ""}
variable oidc_url {}
variable realm {}


variable namespace { default = "devops-harbor" }


locals {
  oidc_endpoint = var.oidc_url
  oidc_name = coalesce(var.oidc_name, var.name)
  fqdn = "${var.name}.${var.domain}"
  url = "https://${local.fqdn}"
  oidc_callback = "${local.url}/c/oidc/callback"
}

