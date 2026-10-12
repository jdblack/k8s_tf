variable "namespace" {
  type    = string
  default = "kube-certificates"
}

# The letsencrypt ClusterIssuer's route53 DNS-01 credentials.
variable "dns01" {
  type = map(any)
}

variable "external_issuer_name" {
  type    = string
  default = "letsencrypt"
}

variable "ca_issuer" {
  type    = string
  default = "linuxguru-ca"
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
  default = "v1.21.2"
}
