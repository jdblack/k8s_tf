# SSO gate for the SeaweedFS admin UI: an HTTPS listener + HTTPRoute on the private
# gateway targeting a co-located authentik proxy outpost (so that hop is
# same-namespace). MANTLE only: core creates authentik and cannot talk to its API in
# the same apply.

variable "namespace" {
  type        = string
  default     = "kube-storage"
  description = "Namespace SeaweedFS (and this outpost + listener) run in."
}

variable "domain" {
  type        = string
  description = "Private domain; the admin UI is served at admin.<app_name>.<domain>."
}

variable "cert_issuer" {
  type        = string
  description = "ClusterIssuer for the listener cert (see modules/cert_manager)."
}

variable "app_name" {
  type        = string
  default     = "seaweedfs"
  description = "SeaweedFS release name; used for the hostname and the admin pod selector."
}

# Defaults to admin.<app_name>.<domain>.
variable "admin_host" {
  type    = string
  default = null
}

variable "admin_service" {
  type        = string
  default     = "seaweedfs-admin"
  description = "ClusterIP Service the admin UI listens on (the outpost's proxy target)."
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

variable "group_name" {
  type        = string
  default     = "storage"
  description = "authentik group bound to the app; add members in the UI."
}

# dashboard-icons has no seaweedfs entry, so this comes from selfh.st via jsDelivr.
variable "icon" {
  type        = string
  default     = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/seaweedfs.svg"
  description = "Bookmark-tile icon URL for the authentik app; null = no icon."
}
