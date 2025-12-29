variable namespace { type = string }
variable name { default = "transmission" }

variable helm_repo { default = "oci://ghcr.io/lexfrei/charts" }
variable chart { default = "transmission" }

variable cert_issuer { type = string }
variable ingress_class { type = string } 
variable domain { type = string } 

variable config_size { default = "1Gi" }
variable movies_pvc { type = string }

locals {
  fqdn = "${var.name}.${var.domain}"

  helm_values = {
    persistence = {
      downloads = {
        type = "pvc"
        existingClaim = var.movies_pvc
        accessMode = "ReadWriteMany"
      }
    }
    service = {
      torrent = {
        type = "LoadBalancer"
        annotations = {
          "metallb.io/address-pool" = "default"
        }
      }
    }
    ingress = {
      annotations = {
        "cert-manager.io/cluster-issuer" = var.cert_issuer,
        "external-dns.alpha.kubernetes.io/hostname" = local.fqdn,
      }
      enabled = true
      className = var.ingress_class
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
    }
  }
}
