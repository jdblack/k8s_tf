variable "namespace" { default = "kube-backup" }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }
variable "monitoring_namespace" { default = "monitoring" }

variable "bucket" { type = string }
variable "region" { type = string }
variable "endpoint" { type = string }

# Offsite: a second BSL, used only by the weekly schedules.
variable "offsite_bucket" { type = string }
variable "offsite_region" { type = string }
variable "offsite_endpoint" { type = string }
variable "offsite_access_key" { type = string }
variable "offsite_secret_key" { type = string }

variable "user" { default = "velero" }
variable "role" { default = "admin" }

variable "seaweedfs_namespace" { default = "kube-storage" }
variable "seaweedfs_release" { default = "seaweedfs-s3" }
variable "seaweedfs_container" { default = "seaweedfs" }
variable "seaweedfs_master" { default = "seaweedfs-master:9333" }

# Chart 12.2.0 ships Velero v1.18.2.
variable "helm_version" { default = "12.2.0" }
variable "aws_plugin_image" { default = "velero/velero-plugin-for-aws:v1.14.0" }
