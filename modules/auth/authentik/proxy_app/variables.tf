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

variable "access_token_validity" {
  type        = string
  default     = "days=7"
  description = "App session lifetime as an authentik duration. The outpost sizes its session cookie and its on-disk session TTL from this, and never renews them, so the minutes=10 default signs idle tabs out and the app's own in-page reconnects get 302'd into the login flow."
}
