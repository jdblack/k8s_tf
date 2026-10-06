variable "namespace" {
  type        = string
  default     = "calico-system"
  description = "Namespace Whisker/Goldmane run in; the outpost and listener too."
}

variable "domain" {
  type        = string
  description = "Private domain; UI at whisker.<domain>."
}

variable "cert_issuer" {
  type        = string
  description = "ClusterIssuer for the listener cert."
}

variable "gateway_name" {
  type    = string
  default = "private"
}

variable "gateway_namespace" {
  type    = string
  default = "kube-network"
}

variable "whisker_service" {
  type    = string
  default = "whisker"
}

variable "whisker_port" {
  type    = number
  default = 8081
}

variable "auth_namespace" {
  type    = string
  default = "kube-auth"
}

variable "outpost_name" {
  type    = string
  default = "whisker-proxy"
}

variable "outpost_service" {
  type    = string
  default = "whisker-auth"
}

variable "icon" {
  type        = string
  default     = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/calico.svg"
  description = "authentik app icon URL; null = none."
}

variable "system_namespace" {
  type    = string
  default = "kube-system"
}
