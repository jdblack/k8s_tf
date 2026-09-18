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

variable "backend_name" {
  type        = string
  description = "Route backend: the authentik outpost Service for an auth-gated app, else the app's own Service."
}

variable "backend_port" { type = number }

variable "route_name" {
  type        = string
  default     = null
  description = "HTTPRoute name; default <name>."
}
