
variable "name" {}
variable "redirect_uri" { type = string }

# Codified rather than set by hand in the authentik UI, so a `tofu apply` reconciles
# to the intended values instead of resetting the tile icon to null.
variable "meta_icon" {
  type    = string
  default = null
}

variable "open_in_new_tab" {
  type    = bool
  default = false
}


