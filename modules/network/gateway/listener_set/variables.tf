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
  type        = string
  default     = ""
  description = "ClusterIssuer name for cert-manager gateway-shim to provision cert-<hostname> (HTTPS listeners only). Ignored for HTTP listeners."
}

variable "hostname" {
  type        = string
  default     = null
  description = "Optional full hostname override for the listener/cert (defaults to <name>.<domain>); useful for sub-subdomains like admin.seaweedfs.<domain>."
}

variable "gateway_name" {
  type    = string
  default = "private"
}

variable "gateway_namespace" {
  type    = string
  default = "kube-network"
}

variable "port" {
  type    = number
  default = 443
}

variable "protocol" {
  type    = string
  default = "HTTPS"
}
