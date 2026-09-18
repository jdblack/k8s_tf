variable "namespace" {
  type = string
}

variable "apps" {
  type = map(object({
    external_host = string
    internal_host = string
    icon          = optional(string)
  }))
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

variable "image" { default = "ghcr.io/goauthentik/proxy" }

variable "image_tag" { default = "2025.10.3" }
