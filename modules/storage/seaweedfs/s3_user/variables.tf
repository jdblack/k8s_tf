variable "user" {
  type        = string
  description = "S3 identity to converge."
}

variable "bucket" {
  type        = string
  description = "Bucket every policy this user carries is scoped to."
}

variable "role" {
  type        = string
  default     = "admin"
  description = "Bucket-scoped role: readonly, readwrite or admin."

  validation {
    condition     = contains(["readonly", "readwrite", "admin"], var.role)
    error_message = "role must be readonly, readwrite or admin."
  }
}

variable "namespace" {
  type        = string
  description = "Namespace the credential Secret is written to."
}

variable "secret_name" {
  type        = string
  default     = null
  description = "Credential Secret name; defaults to <user>-s3."
}

variable "access_key_key" {
  type        = string
  default     = "accessKey"
  description = "Key the access key is published under; the oCIS chart reads accessKey/secretKey."
}

variable "secret_key_key" {
  type    = string
  default = "secretKey"
}

variable "access_key_length" { default = 20 }
variable "secret_key_length" { default = 40 }

variable "seaweedfs_namespace" { default = "kube-storage" }
variable "seaweedfs_release" { default = "seaweedfs-s3" }
variable "seaweedfs_container" { default = "seaweedfs" }
variable "seaweedfs_master" { default = "seaweedfs-master:9333" }
