variable namespace { type = string }
variable name { default = "prowlarr" }

variable helm_repo { default = "oci://ghcr.io/m0nsterrr/helm-charts" }
variable chart { default = "prowlarr" }

variable cert_issuer { type = string }
variable ingress_class { type = string } 
variable domain { type = string } 

variable config_size { default = "1Gi" }

locals {
  fqdn = "${var.name}.${var.domain}"

  helm_values = {
    ingress = {
      annotations = {
        "cert-manager.io/cluster-issuer" = var.cert_issuer,
        "external-dns.alpha.kubernetes.io/hostname" = local.fqdn,
      }
      enabled = true
      ingressClassName = var.ingress_class
      url = local.fqdn

      tls = [
        {
          hosts      = [local.fqdn]
          secretName = "cert-${local.fqdn}"
        }
      ]
      hosts = [
        {
          host = local.fqdn
          paths = [
            {
              path     = "/"
              pathType = "ImplementationSpecific"
            }
          ]
        }
      ]
      service = {
        type = "LoadBalancer"
      }
    }
  }
}
