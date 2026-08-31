variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "domain" {
  type = string
}

variable "cert_issuer" {
  type = string
}

variable "gateway_name" {
  type    = string
  default = "media-private"
}

variable "gateway_namespace" {
  type    = string
  default = "media"
}

variable "port" {
  type    = number
  default = 443
}

variable "protocol" {
  type    = string
  default = "HTTPS"
}
