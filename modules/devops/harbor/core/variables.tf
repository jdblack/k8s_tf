variable "namespace" { type = string }
variable "name" { default = "harbor" }
variable "domain" { type = string }
variable "cert_issuer" { type = string }
variable "auth_secret" { type = string }

variable "helm_version" { default = "1.19.2" }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }
