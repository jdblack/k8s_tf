variable "namespace" { default = "media" }
variable "domain" { type = string }

variable "name" { default = "suggestarr" }

variable "image" { default = "ghcr.io/giuseppe99barchetta/suggestarr" }
variable "image_tag" { default = "v2.15.0" }

variable "web_port" { default = 5000 }

variable "config_size" { default = "1Gi" }

variable "cert_issuer" { type = string }
variable "gateway_name" { default = "media-private" }
variable "gateway_namespace" { default = "media" }

variable "auth_outpost" {
  type = object({
    outpost_id            = string
    service               = string
    port                  = number
    access_token_validity = string
  })
  default     = null
  description = "Gate the app behind this outpost; null routes straight to the app."
}

variable "icon" {
  type        = string
  default     = null
  description = "authentik icon URL; null guesses the dashboard-icons CDN, empty string for no icon."
}

variable "auth_trusted_header" { default = "X-authentik-username" }

variable "pod_cidr" { type = string }
variable "host_cidr" { type = string }
