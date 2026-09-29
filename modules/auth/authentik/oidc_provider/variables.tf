variable "name" { type = string }
variable "redirect_uri" { type = string }

variable "extra_redirect_uris" {
  type        = list(string)
  default     = []
  description = "Additional authorization redirect URIs; a mobile client's custom scheme cannot be the single one."
}

variable "group_id" {
  type        = string
  default     = null
  description = "authentik group allowed to use the application; null leaves it unbounded."
}

variable "bind_app" {
  type        = bool
  default     = false
  description = "Bind the application to this module's own <name>-admin and <name>-user groups; off leaves the app unbounded unless group_id is set."
}

variable "meta_icon" {
  type    = string
  default = null
}

variable "meta_launch_url" {
  type        = string
  default     = null
  description = "Dashboard launch URL; null leaves the tile present but unlinked."
}

variable "open_in_new_tab" {
  type    = bool
  default = false
}
