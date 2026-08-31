
variable "namespace" {}
variable "name" { default = "harbor" }
variable "domain" { type = string }
variable "cert_issuer" { type = string }
variable "auth_secret" {}

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }
