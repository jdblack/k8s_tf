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
  description = "ClusterIssuer for the cert-manager gateway-shim to provision cert-<hostname>. HTTPS listeners only."
}

variable "hostname" {
  type        = string
  default     = null
  description = "Full hostname override for the listener and cert; default <name>.<domain>."
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
