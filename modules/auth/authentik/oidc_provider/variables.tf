variable "name" {}
variable "redirect_uri" { type = string }

variable "meta_icon" {
  type    = string
  default = null
}

variable "open_in_new_tab" {
  type    = bool
  default = false
}
