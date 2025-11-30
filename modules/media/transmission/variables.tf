variable namespace { type = string }
variable cert_issuers { type = map }
variable name { default = "transmission" }
variable config_size { default = "1Gi" }
variable helm_repo { default = "oci://ghcr.io/lexfrei/charts" }
variable chart { default = "transmission" }
variable visibility { default = "private" }
variable download_pvc { type = string }

locals {
  sub = var.visibility == "private" ? ".vn" : "" 
  fqdn = "${var.name}${local.sub}.linuxguru.net"
  issuer = var.cert_issuers[var.visibility]

  helm_values = {
    persistence = {
      downloads = {
        type = "pvc"
        existingClaim = var.download_pvc
        storageClassName = "longhorn"
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
        "cert-manager.io/cluster-issuer" = local.issuer,
        "external-dns.alpha.kubernetes.io/hostname" = local.fqdn,
      }
      enabled = true
      className = "private"
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
