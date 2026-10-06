variable "name" { type = string }
variable "slug" { type = string }

variable "launch_url" {
  type        = string
  description = "Where the tile points; the app's own login page."
}

variable "icon" {
  type    = string
  default = null
}

variable "open_in_new_tab" {
  type    = bool
  default = true
}
