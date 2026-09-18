variable "wireguard_name" {
  type    = string
  default = "wg-server"
}

variable "namespace" {
  type    = string
  default = "wireguard-system"
}

variable "create_namespace" {
  type    = bool
  default = true
}

variable "external_address" {
  type    = string
  default = ""
}

variable "dns" {
  type    = string
  default = ""
}

variable "dns_search_domains" {
  type    = list(string)
  default = []
}

variable "peers" {
  type    = list(string)
  default = []
}

variable "helm_version" {
  type    = string
  default = "0.3.0"
}

variable "image_tag" {
  type    = string
  default = "v2.11.0"
}
