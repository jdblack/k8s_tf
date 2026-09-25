variable "namespace" {
  type        = string
  default     = "monitoring"
  description = "Namespace Alertmanager, the outpost and the listener run in."
}

variable "domain" {
  type        = string
  description = "Private domain; the UI is at <name>.<domain>."
}

variable "cert_issuer" {
  type        = string
  description = "ClusterIssuer for the listener cert."
}

variable "name" {
  type        = string
  default     = "alertmanager"
  description = "Hostname prefix and the authentik app slug."
}

variable "service" {
  type        = string
  default     = "prometheus-kube-prometheus-alertmanager"
  description = "ClusterIP Service the outpost proxies to."
}

variable "port" {
  type        = number
  default     = 9093
  description = "Alertmanager's HTTP port."
}

variable "http_port" {
  type        = number
  default     = 9000
  description = "Port the outpost serves on; the backend_port of every route pointing at it."
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
  default = "monitoring-proxy"
}

variable "outpost_service" {
  type    = string
  default = "alertmanager-auth"
}

variable "group_name" {
  type        = string
  default     = "monitoring"
  description = "authentik group bound to the app; add members in the UI."
}
