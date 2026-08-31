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

variable "gateway_ips" {
  type = object({
    public  = string
    private = string
  })
  description = "MetalLB IPs to pin the public/private gateway data-plane Services to (the IPs the old ingress-nginx controllers held, so DNS / NAT / firewall rules keep working)."
}

variable "internal_ingress_class" {
  type    = string
  default = "internal"
}

