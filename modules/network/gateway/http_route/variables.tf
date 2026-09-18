variable "name" {
  type = string
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

variable "backend_name" {
  type        = string
  description = "Service this route forwards to."
}

variable "backend_port" {
  type        = number
  description = "Port on that Service."
}

variable "parent_kind" {
  type        = string
  default     = "ListenerSet"
  description = "Kind of the parentRef: ListenerSet, or Gateway for a route attached directly."
}

variable "parent_name" {
  type        = string
  default     = null
  description = "parentRef name; default the route name, i.e. the app's ListenerSet."
}

variable "parent_namespace" {
  type        = string
  default     = null
  description = "parentRef namespace; default the route namespace."
}

variable "annotations" {
  type        = map(string)
  default     = {}
  description = "Extra annotations, merged over the external-dns hostname annotation."
}
