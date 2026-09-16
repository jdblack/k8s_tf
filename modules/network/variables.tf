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

# Calico ships as the tigera-operator chart; the release is named `calico`. The CRDs come
# from the same version tag (see calico.tf).
variable "helm_calico_version" {
  type    = string
  default = "v3.32.2"
}

variable "helm_external_dns_version" {
  type    = string
  default = "1.22.0"
}

