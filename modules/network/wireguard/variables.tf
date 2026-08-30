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

# Public endpoint baked into every peer config (e.g. home.linuxguru.net).
# Empty string -> the operator falls back to the LoadBalancer/service address.
variable "external_address" {
  type    = string
  default = ""
}

# DNS server handed to peers (e.g. 192.168.0.2). Empty string -> the operator
# defaults to kube-dns, falling back to a public resolver.
variable "dns" {
  type    = string
  default = ""
}

# Search domains handed to peers; joined with ", " into the operator's single
# dnsSearchDomain string -> clients get `DNS = <dns>, <domain>, <domain>`.
variable "dns_search_domains" {
  type    = list(string)
  default = []
}

variable "peers" {
  type    = list(string)
  default = []
}

variable "chart_version" {
  type    = string
  default = "0.3.0"
}

variable "image_tag" {
  type    = string
  default = "v2.11.0"
}
