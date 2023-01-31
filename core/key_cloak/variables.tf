variable name {
  type = string
  default = "keycloak"
}

variable adminUser {
  type = string
  default = "admin"
}

variable password {
  type = string
  default = null
}

variable helm_url {
  type = string
  default = "https://charts.bitnami.com/bitnami"
}

variable chart  {
  default = null
  type = string
}

variable "namespace" {
  default = null
  type = string
}

locals {
  chart = coalesce(var.chart, var.name)
  namespace = coalesce(var.namespace, var.name)
  password = coalesce(var.password, random_password.keycloak_admin.result)
}


variable tld {
  type = string
}

variable cert_issuer {
  type = string
}


locals {
  domain = "${var.name}.${var.tld}"
  domains = [
    var.name,
    local.domain
  ]
}
