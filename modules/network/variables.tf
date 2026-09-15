variable "internal_dns" {
  type = object({
    server = string
    domain = string
    client = string
    secret = string
  })
}

variable "metal_networks" {
  type = string
}

variable "namespace" {
  type    = string
  default = "kube-network"
}

variable "helm_metallb_version" {
  type    = string
  default = "0.16.1"
}

