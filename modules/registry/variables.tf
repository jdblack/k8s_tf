
variable name {
  type = string
  default = "registry"
}

variable tld {
  type = string
}

variable namespace {
  type = string
  default = null
}

variable repository {
  type = string
  default = "https://helm.melillo.me/"
}

variable chart {
  type = string
  default = "docker-registry"
}

variable docker_user {
  type = string
  default = "docker"
}

variable cert_issuer {
  type = string
}

variable secret_name {
  type = string
}
