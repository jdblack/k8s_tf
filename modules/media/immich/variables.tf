variable "namespace" { default = "media" }
variable "name" { default = "immich" }

variable "domain" { type = string }
variable "cert_issuer" { type = string }
variable "gateway_name" { default = "media-private" }
variable "gateway_namespace" { default = "media" }

variable "library_pvc" { type = string }

variable "auth_gateway_name" { default = "private" }
variable "auth_gateway_namespace" { default = "kube-network" }

variable "helm_version" { default = "0.13.4" }

# Server and machine-learning move together: they are the same Immich release.
variable "image_tag" { default = "v3.3.0" }

variable "storage_class" { default = "longhorn" }

variable "ml_cache_size" { default = "10Gi" }

variable "postgres_image" { default = "ghcr.io/immich-app/postgres" }

# VectorChord is not optional: the server refuses to boot without a supported version.
variable "postgres_image_tag" { default = "17-vectorchord0.4.3-pgvector0.8.0" }
variable "postgres_size" { default = "20Gi" }

variable "metrics_enabled" { default = true }
variable "monitoring_namespace" { default = "monitoring" }

variable "icon" {
  type        = string
  default     = null
  description = "authentik icon URL; null guesses the dashboard-icons CDN, empty string for no icon."
}
