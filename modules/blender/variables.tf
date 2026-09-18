variable "namespace" { default = "blender" }
variable "name" { default = "blender" }
variable "samba_user" { default = "jblack" }
variable "domain" { type = string }

variable "samba_image" {
  type    = string
  default = "dockurr/samba:4.23.10"
}

variable "mdns_enabled" {
  type    = bool
  default = true
}

variable "mdns_image" {
  type    = string
  default = "flungo/avahi@sha256:5f22bd9a431373f3008c64dcb05dcf3b6c7ff3e7909be1fe2a2c29a0e39b36a7"
}

variable "mdns_node_selector" {
  type    = map(string)
  default = {}
}
