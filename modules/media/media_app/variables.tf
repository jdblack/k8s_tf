variable "namespace" { type = string }
variable "name" { type = string }

variable "helm_repo" { type = string }
variable "chart" { type = string }
variable "helm_version" { type = string }

variable "helm_values" {
  type        = any
  default     = {}
  description = "Chart values, verbatim. Each chart here has its own shape, so the caller composes this."
}

variable "domain" { type = string }
variable "cert_issuer" { type = string }
variable "gateway_name" { default = "media-private" }
variable "gateway_namespace" { default = "media" }

variable "port" {
  type        = number
  default     = 80
  description = "The app's own Service port: pinned into the chart values unless the caller manages the service block, and the outpost's upstream."
}

variable "backend_name" {
  type        = string
  default     = null
  description = "Route backend when ungated; default the app's own Service name."
}

variable "auth_outpost" {
  type = object({
    outpost_id            = string
    group_id              = string
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
