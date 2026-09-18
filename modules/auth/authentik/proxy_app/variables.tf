variable "name" {
  type        = string
  description = "App slug: the authentik provider/application name, and the default Service name."
}

variable "service" {
  type        = string
  default     = null
  description = "Service the outpost proxies to; default the app's own name."
}

variable "namespace" { type = string }

variable "domain" { type = string }

variable "hostname" {
  type        = string
  default     = null
  description = "External hostname; default <name>.<domain>."
}

variable "port" {
  type        = number
  description = "Service port the outpost proxies to."
}

variable "icon" {
  type        = string
  default     = null
  description = "Icon URL; null guesses the dashboard-icons CDN, empty string for no icon."
}

variable "outpost_id" {
  type        = string
  description = "The authentik outpost that serves this app."
}

variable "group_id" {
  type        = string
  description = "Group bound to the app; its members get access."
}
