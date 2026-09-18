variable "namespace" { default = "argo" }
variable "domain" { type = string }
variable "cert_issuer" { type = string }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }
