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

variable "session_validity" {
  type        = string
  default     = "days=7"
  description = "access_token_validity of every provider here; only used to roll the outpost, which builds its session cookie TTL (validity + 1) once at boot and reuses that store across config refreshes."
}

variable "provider_ids" {
  type        = list(string)
  default     = []
  description = "Providers attached when the outpost is created. authentik refuses a create with an empty list, so a new outpost has to be built after the provider it serves."
}
