variable "namespace" { type = string }
variable "name" { default = "prowlarr" }

variable "helm_repo" { default = "oci://ghcr.io/m0nsterrr/helm-charts" }
variable "chart" { default = "prowlarr" }

variable "domain" { type = string }

variable "cert_issuer" { type = string }
variable "gateway_name" { default = "media-private" }
variable "gateway_namespace" { default = "media" }
