# Calico Whisker flow-log UI, exposed like the media apps: an authentik proxy
# outpost in front + an HTTPS listener on the shared private gateway, plus
# pod-scoped NetworkPolicies that stop every other cluster pod from reading the
# flow data directly.
#
# Whisker (and Goldmane, its aggregator) live in calico-system. The outpost is
# co-located there so the outpost -> whisker hop is same-namespace.

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
  description = "ClusterIssuer for the listener cert (the private CA)."
}

variable "gateway_name" {
  type    = string
  default = "private"
}

variable "gateway_namespace" {
  type    = string
  default = "kube-network"
}

# Whisker Service/port inside var.namespace (the outpost's proxy target).
variable "whisker_service" {
  type    = string
  default = "whisker"
}

variable "whisker_port" {
  type    = number
  default = 8081
}

# authentik wiring
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
  default     = null
  description = "Bookmark-tile icon URL for the authentik app; null = no icon (there is no upstream calico/whisker icon)."
}

# LAN / node CIDRs (kept for parity with the other network submodules; not
# used by the ingress policies here -- see main.tf for why goldmane cannot be
# tightened).
variable "lan_cidrs" {
  type    = list(string)
  default = []
}

variable "system_namespace" {
  type    = string
  default = "kube-system"
}
