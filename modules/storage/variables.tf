variable "namespace" { type = string }
variable "longhorn_namespace" { default = "longhorn-system" }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }

variable "monitoring_namespace" { default = "monitoring" }

variable "helm_longhorn_url" { default = "https://charts.longhorn.io" }
variable "helm_longhorn_chart" { default = "longhorn" }
variable "helm_longhorn_version" { default = "1.12.1" }
variable "helm_snapshot_controller_version" { default = "5.3.0" }

variable "backup_enabled" { default = true }
variable "backup_bucket" { type = string }
variable "backup_region" { type = string }
variable "backup_endpoint" { type = string }

variable "backup_offsite_bucket" { type = string }
variable "backup_offsite_region" { type = string }
variable "backup_offsite_endpoint" { type = string }
variable "backup_offsite_access_key" { type = string }
variable "backup_offsite_secret_key" { type = string }

variable "backup_buckets_dest_bucket" { type = string }
variable "backup_buckets_region" { type = string }
variable "backup_buckets_endpoint" { type = string }
variable "backup_buckets_access_key" { type = string }
variable "backup_buckets_secret_key" { type = string }
