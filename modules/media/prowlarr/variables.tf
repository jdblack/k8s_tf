variable "namespace" { type = string }
variable "name" { default = "prowlarr" }

variable "helm_repo" { default = "oci://ghcr.io/m0nsterrr/helm-charts" }
variable "chart" { default = "prowlarr" }

variable "domain" { type = string }

variable "cert_issuer" { type = string }
variable "gateway_name" { default = "media-private" }
variable "gateway_namespace" { default = "media" }

locals {
  fqdn = "${var.name}.${var.domain}"

  helm_values = {
    ingress = {
      enabled = false
    }
    route = {
      main = {
        enabled   = true
        hostnames = [local.fqdn]
        parentRefs = [
          {
            group       = "gateway.networking.k8s.io"
            kind        = "ListenerSet"
            name        = var.name
            namespace   = var.namespace
            sectionName = var.name
          }
        ]
        annotations = {
          "external-dns.alpha.kubernetes.io/hostname" = local.fqdn
        }
      }
    }
  }
}
