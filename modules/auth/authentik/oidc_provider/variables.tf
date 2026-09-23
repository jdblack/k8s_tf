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

variable "meta_icon" {
  type    = string
  default = null
}

variable "open_in_new_tab" {
  type    = bool
  default = false
}
