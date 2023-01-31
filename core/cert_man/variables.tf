variable namespace { 
  type = string
  default="kube-certman"
}
variable cert_version {
  type = string
  default="1.10.1"
}

variable issuer_name {
  type=string
}

variable ca_certfile {
  type = string
  default="~/.ssl/ca.crt"
}

variable ca_keyfile {
  type = string
  default = "~/.ssl/ca.key"
}

