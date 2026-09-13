variable "prometheus_name" { default = "prometheus" }

variable "namespace" {}
variable "cert_issuer" {}
variable "domain" {}
variable "grafana_name" { default = "grafana" }

# Global-admin group matched in addition to the app's own `<grafana_name>-admin`
# group: authentik's built-in superuser group. The name is a literal authentik
# ships, and it must match exactly as it appears in the `groups` claim.
variable "admin_group" {
  type    = string
  default = "authentik Admins"
}

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }

