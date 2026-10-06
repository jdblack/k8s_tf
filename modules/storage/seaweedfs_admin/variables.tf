variable "namespace" {
  type        = string
  default     = "kube-storage"
  description = "Namespace SeaweedFS, the outpost and the listener run in."
}

variable "domain" {
  type        = string
  description = "Private domain; admin UI at admin.<app_name>.<domain>."
}

variable "cert_issuer" {
  type        = string
  description = "ClusterIssuer for the listener cert."
}

variable "app_name" {
  type        = string
  default     = "seaweedfs"
  description = "SeaweedFS release name; feeds the hostname and the admin pod selector."
}

variable "admin_host" {
  type    = string
  default = null
}

variable "admin_service" {
  type        = string
  default     = "seaweedfs-admin"
  description = "ClusterIP Service the admin UI listens on; the outpost proxies to it."
}

variable "admin_port" {
  type        = number
  default     = 23646
  description = "Admin Service HTTP port."
}

variable "gateway_name" {
  type    = string
  default = "private"
}

variable "gateway_namespace" {
  type    = string
  default = "kube-network"
}

variable "auth_namespace" {
  type    = string
  default = "kube-auth"
}

variable "outpost_name" {
  type    = string
  default = "seaweedfs-admin-proxy"
}

variable "outpost_service" {
  type    = string
  default = "seaweedfs-admin-auth"
}

variable "icon" {
  type        = string
  default     = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/seaweedfs.svg"
  description = "authentik app icon URL; null = none."
}
