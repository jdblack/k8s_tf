variable "name" {
  type        = string
  description = "App/listener name; the hostname defaults to <name>.<domain> and the ListenerSet + default route name derive from it."
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
  description = "Optional full hostname override (sub-subdomains like admin.seaweedfs.<domain>)."
}

variable "cert_issuer" {
  type        = string
  default     = ""
  description = "ClusterIssuer for the cert-manager gateway-shim (HTTPS only)."
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

# Optional HTTPRoute. Leave empty for apps whose chart renders its own route.
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
  description = "HTTPRoute name (defaults to <name>); set '<name>-auth' when routing to the authentik outpost."
}

variable "annotations" {
  type    = map(string)
  default = {}
}