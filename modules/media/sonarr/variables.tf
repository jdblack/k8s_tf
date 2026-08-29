variable "namespace" { type = string }
variable "name" { default = "sonarr" }

variable "helm_repo" { default = "oci://ghcr.io/m0nsterrr/helm-charts" }
variable "chart" { default = "sonarr" }

variable "cert_issuer" { type = string }
variable "ingress_class" { type = string }
variable "domain" { type = string }

variable "config_size" { default = "1Gi" }
variable "movies_pvc" { type = string }
