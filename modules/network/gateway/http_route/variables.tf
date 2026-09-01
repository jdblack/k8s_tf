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
  description = "Optional full hostname override for the route (defaults to <name>.<domain>); useful for sub-subdomains like admin.seaweedfs.<domain>."
}

variable "backend_name" {
  type        = string
  description = "Name of the Service this route forwards to."
}

variable "backend_port" {
  type        = number
  description = "Port of the Service this route forwards to."
}

variable "parent_kind" {
  type        = string
  default     = "ListenerSet"
  description = "Kind of the route's parentRef (ListenerSet, or Gateway for routes attached directly to a gateway)."
}

variable "parent_name" {
  type        = string
  default     = null
  description = "Name of the parentRef object (defaults to the route name, i.e. the app's ListenerSet)."
}

variable "parent_namespace" {
  type        = string
  default     = null
  description = "Namespace of the parentRef object (defaults to the route namespace)."
}

variable "annotations" {
  type        = map(string)
  default     = {}
  description = "Extra annotations merged over the external-dns hostname annotation."
}
