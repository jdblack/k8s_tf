variable namespace {
  type = string
}
variable name {
  type = string
  default="cinc"
}
variable domain  {
  type = string
}
variable cert_issuer {
  type = string
}

variable registry_info {
  type = map
}

locals {
  fqdn = "${var.name}.${var.domain}"
  search_fqdn="search-${local.fqdn}"
  lb_cert = "lb-${var.name}-cert"
  registry_secret = "registry-auth"

}

