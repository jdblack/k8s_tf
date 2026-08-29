variable "namespace" {
  type    = string
  default = "kube-certificates"
}

variable "data" {
  type = map(any)
}

variable "external_issuer_name" {
  type    = string
  default = "letsencrypt"
}

variable "acme_email" {
  type = string
}

variable "ca_certfile" {
  type    = string
  default = "~/.ssl/ca.crt"
}

variable "ca_keyfile" {
  type    = string
  default = "~/.ssl/ca.key"
}

