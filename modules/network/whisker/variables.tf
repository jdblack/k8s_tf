variable "namespace" {
  type        = string
  default     = "calico-system"
  description = "Namespace Whisker/Goldmane run in (also where the outpost + listener are created)."
}

variable "domain" {
  type        = string
  description = "Private domain the UI is served under (hostname is whisker.<domain>)."
}

variable "cert_issuer" {
  type        = string
  description = "ClusterIssuer for the listener cert (see modules/cert_manager)."
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

variable "group_name" {
  type        = string
  default     = "platform"
  description = "authentik group bound to the app; add members in the UI."
}

variable "icon" {
  type        = string
  default     = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/calico.svg"
  description = "Bookmark-tile icon URL for the authentik app; null = no icon."
}

variable "system_namespace" {
  type    = string
  default = "kube-system"
}
