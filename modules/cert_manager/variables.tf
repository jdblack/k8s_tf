variable namespace { 
  type = string
  default="kube-certificates"
}
variable cert_version {
  type = string
  default="1.16.2"
}

variable data {
  type = map
}

variable external_issuer_name {
  type = string
  default = "letsencrypt"
}

variable ca_certfile {
  type = string
  default="~/.ssl/ca.crt"
}

variable ca_keyfile {
  type = string
  default = "~/.ssl/ca.key"
}

