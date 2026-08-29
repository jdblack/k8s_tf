variable "namespace" { type = string }
variable "name" { default = "prowlarr" }

variable "helm_repo" { default = "oci://ghcr.io/m0nsterrr/helm-charts" }
variable "chart" { default = "prowlarr" }

variable "cert_issuer" { type = string }
variable "ingress_class" { type = string }
variable "domain" { type = string }
