variable "namespace" {}
variable "name" { default = "authentik" }
variable "domain" {}
variable "cert_issuer" {}
variable "fqdn" { default = "" }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }
