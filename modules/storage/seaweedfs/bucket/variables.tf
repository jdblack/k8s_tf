variable "bucket" {
  type        = string
  description = "Bucket name to converge."
}

variable "owner" {
  type        = string
  default     = ""
  description = "Identity name that owns the bucket. Non-admin S3 users can only reach buckets they own, so leave this off only for admin-only buckets."
}

variable "seaweedfs_namespace" { default = "kube-storage" }
variable "seaweedfs_release" { default = "seaweedfs-s3" }
variable "seaweedfs_container" { default = "seaweedfs" }
variable "seaweedfs_master" { default = "seaweedfs-master:9333" }
