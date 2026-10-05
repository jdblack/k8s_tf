variable "name" {
  type        = string
  description = "App/listener name: hostname default <name>.<domain>, and the ListenerSet and route names derive from it."
}

variable "namespace" {
  type = string
}

variable "domain" {
  type = string
}

variable "hostname" {
  type        = string
  default     = null
  description = "Full hostname override; default <name>.<domain>."
}

variable "cert_issuer" {
  type        = string
  default     = ""
  description = "ClusterIssuer for the cert-manager gateway-shim (HTTPS listeners only)."
}

variable "gateway_name" {
  type    = string
  default = "private"
}

variable "gateway_namespace" {
  type    = string
  default = "kube-network"
}

variable "port" {
  type    = number
  default = 443
}

variable "protocol" {
  type    = string
  default = "HTTPS"
}

variable "backend_name" {
  type    = string
  default = ""
}

variable "backend_port" {
  type    = number
  default = null
}

variable "route_name" {
  type        = string
  default     = null
  description = "HTTPRoute name; default <name>. Use '<name>-auth' when the route forwards to an authentik outpost."
}

variable "annotations" {
  type    = map(string)
  default = {}
}

variable "filters" {
  type        = list(any)
  default     = []
  description = "Extra HTTPRoute rule filters (e.g. ResponseHeaderModifier) for the route."
}
