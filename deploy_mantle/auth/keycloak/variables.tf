variable realm {}
variable realm_display {}

variable domain {}
variable keycloak_host { default = "keycloak" }

locals {
  key_url = "https://${var.keycloak_host}.${var.domain}"
  key_realm_url = "${local.key_url}/realms/${var.realm}"
}

output keycloak_url { value = local.key_realm_url }
output realm_url { value = local.key_realm_url }

