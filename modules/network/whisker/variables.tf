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

# Bookmark-tile icon for the authentik application. No whisker-specific tile
# exists in any icon set (Calico ships only a React component, no SVG), so use the
# Calico brand mark. dashboard-icons has no calico entry either, hence selfh.st
# via jsDelivr.
variable "icon" {
  type        = string
  default     = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/calico.svg"
  description = "Bookmark-tile icon URL for the authentik app; null = no icon."
}

variable "system_namespace" {
  type    = string
  default = "kube-system"
}
