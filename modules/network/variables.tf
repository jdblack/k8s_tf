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

variable "helm_calico_version" {
  type    = string
  default = "v3.32.2"
}

variable "helm_external_dns_version" {
  type    = string
  default = "1.22.0"
}

# Source of truth: gates the CRDs, so ngf-public and ngf-private must match it.
variable "helm_ngf_version" {
  default     = "2.7.1"
  description = "nginx-gateway-fabric chart version; feeds the chart, the CRD kustomize refs and their triggers_replace."
}
