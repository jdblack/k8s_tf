variable "namespace" { type = string }
variable "longhorn_namespace" { default = "longhorn-system" }

# Passed through to the SeaweedFS tier.
variable "cert_issuer" { type = string }
variable "domains" { type = map(any) }
variable "data_center" { type = string }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }

variable "helm_longhorn_url" { default = "https://charts.longhorn.io" }
variable "helm_longhorn_chart" { default = "longhorn" }
variable "helm_longhorn_version" { default = "1.12.1" }
variable "helm_snapshot_controller_version" { default = "5.3.0" }

variable "backup_enabled" { default = true }
variable "backup_bucket" { type = string }
variable "backup_region" { type = string }
variable "backup_endpoint" { type = string }
