variable "namespace" { type = string }
variable "name" { default = "seerr" }

variable "helm_repo" { default = "oci://ghcr.io/seerr-team/seerr" }
variable "chart" { default = "seerr-chart" }
variable "helm_version" { default = "3.9.1" }

variable "domain" { type = string }

variable "config_size" { default = "2Gi" }

variable "cert_issuer" { type = string }
variable "gateway_name" { default = "media-private" }
variable "gateway_namespace" { default = "media" }
