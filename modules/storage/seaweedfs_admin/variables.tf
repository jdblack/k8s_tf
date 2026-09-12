# SSO gate for the SeaweedFS admin UI (`weed admin`).
#
# The admin UI speaks no OIDC, so authentik fronts it as a **proxy outpost** --
# exactly the media / whisker pattern: an HTTPS listener + HTTPRoute on the
# shared private gateway that target the outpost, and the outpost proxies to the
# admin Service once the user has a session.
#
# This module lives in the MANTLE stack: only mantle has the authentik provider
# configured (authentik is created BY the core stack, so core cannot talk to its
# API in the same apply). The SeaweedFS release and its Services stay in core
# (stacks/core/storage.tf) -- this module only adds the auth layer on top and is
# what publishes admin.<release>.<domain> now.
#
# The outpost is co-located in var.namespace (the SeaweedFS namespace) so the
# outpost -> admin hop is same-namespace and needs no cross-namespace policy.

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
  description = "ClusterIssuer for the listener cert (the private CA)."
}

variable "app_name" {
  type        = string
  default     = "seaweedfs"
  description = "SeaweedFS release name; used for the hostname and the admin pod selector."
}

# Full hostname override; defaults to admin.<app_name>.<domain> (the host the
# core seaweedfs module's expose_admin used to publish directly).
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

# authentik wiring
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

# Bookmark-tile icon for the authentik application. dashboard-icons (the set the
# media apps use) has no seaweedfs entry, so this comes from the selfh.st icon
# set via jsDelivr instead -- same versionless-CDN idiom, just a different repo.
variable "icon" {
  type        = string
  default     = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/seaweedfs.svg"
  description = "Bookmark-tile icon URL for the authentik app; null = no icon."
}

variable "system_namespace" {
  type    = string
  default = "kube-system"
}
