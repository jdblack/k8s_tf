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

# Public endpoint baked into every peer config (e.g. home.linuxguru.net); empty -> the
# operator falls back to the LoadBalancer/service address.
variable "external_address" {
  type    = string
  default = ""
}

# DNS server handed to peers (e.g. 192.168.0.2); empty -> kube-dns, then a public resolver.
variable "dns" {
  type    = string
  default = ""
}

# Joined into the operator's single dnsSearchDomain string.
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
