
variable "name" {}
variable "redirect_uri" { type = string }

# Application-launch metadata normally set by hand in the authentik UI. Codified
# here so a `tofu apply` reconciles to the intended values instead of resetting
# the tile icon to null and open_in_new_tab to false.
variable "meta_icon" {
  type    = string
  default = null
}

variable "open_in_new_tab" {
  type    = bool
  default = false
}


