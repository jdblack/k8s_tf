variable "prometheus_name" { default = "prometheus" }

variable "namespace" {}
variable "cert_issuer" {}
variable "domain" {}
variable "grafana_name" { default = "grafana" }
variable "grafana_admin_password" { default = "" }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }
