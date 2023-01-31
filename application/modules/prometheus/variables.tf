
variable namespace {
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

variable oidc_ns { 
  type = string
  default = "keycloak"
}

variable oidc_name {
  type = string
  default = "oidc-prometheus"
}
