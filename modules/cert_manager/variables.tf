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

variable "helm_version" {
  type    = string
  default = "v1.21.1"
}

# The apiserver's endpoint IPs, read by the CALLER (stack root) and passed to the
# firewall's API carve-out. Required whenever this module is called under a module-level
# `depends_on`: that defers data sources inside the module to apply time, so the API netpol
# plans a guessed peer count and the apply dies with "inconsistent final plan".
#
# null = let the firewall module read the endpoints itself.
variable "api_peer_ips" {
  type    = list(string)
  default = null
}

