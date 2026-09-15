variable "namespace" {}
variable "name" { default = "authentik" }
variable "domain" {}
variable "cert_issuer" { type = string }
variable "fqdn" { default = "" }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }
