locals {
  fqdn = "${var.name}.${var.domain}"
}

variable namespace {
  type = string
}

variable name {
  type = string
}

variable domain {
  type = string
}
variable release_name {
  default = "prometheus"
  type=string
}

variable cert_issuer {
  type = string
}

variable helm_url {
  type = string
  default = "https://prometheus-community.github.io/helm-charts"
}

variable chart {
  type = string
  default = "kube-prometheus-stack"
}


variable keycloak_realm {
  type = string
}

variable keycloak_domain {
  type = string
}
