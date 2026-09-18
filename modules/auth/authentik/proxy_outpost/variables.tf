variable "namespace" {
  type = string
}

variable "outpost_name" { default = "media-proxy" }

variable "service_name" { default = "authentik-outpost" }

variable "group_name" { default = "media" }

variable "domain" { type = string }

variable "auth_fqdn" {
  type    = string
  default = null
}

variable "core_namespace" { default = "kube-auth" }

variable "http_port" {
  type        = number
  default     = 9000
  description = "Port the outpost serves on; the backend_port of every route pointing at it."
}

variable "image" { default = "ghcr.io/goauthentik/proxy" }

variable "image_tag" { default = "2025.10.3" }
