variable "prometheus_name" { default = "prometheus" }

variable "namespace" {}
variable "cert_issuer" { type = string }
variable "domain" {}
variable "grafana_name" { default = "grafana" }

# kube-prometheus-stack chart version: pinned deliberately, see helm.tf.
variable "helm_version" { default = "91.4.1" }

# Globally-privileged group matched in addition to the app's own
# `<grafana_name>-admin` group: authentik's built-in superuser group, which must
# match exactly as it appears in the `groups` claim.
variable "admin_group" {
  type    = string
  default = "authentik Admins"
}

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }

