variable "prometheus_name" { default = "prometheus" }

variable "namespace" {}
variable "cert_issuer" { type = string }
variable "domain" {}
variable "grafana_name" { default = "grafana" }

variable "helm_version" { default = "91.4.1" }

variable "admin_group" {
  type    = string
  default = "authentik Admins"
}

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }
