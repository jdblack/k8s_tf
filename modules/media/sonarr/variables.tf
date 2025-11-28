variable namespace { type = string }
variable cert_issuers { type = map }
variable name { default = "sonarr" }
variable config_size { default = "1Gi" }
variable helm_repo { default = "oci://ghcr.io/m0nsterrr/helm-charts" }
variable chart { default = "sonarr" }
variable visibility { default = "private" }
variable download_pvc { type = string }

locals {
  sub = var.visibility == "private" ? ".vn" : "" 
  fqdn = "${var.name}${local.sub}.linuxguru.net"
  issuer = var.cert_issuers[var.visibility]

  helm_values = {
    volumes = [
      {
        name = "downloads"
        persistentVolumeClaim = {
          claimName = var.download_pvc
        }
      },
      {
        name = "media"
        persistentVolumeClaim = {
          claimName = "movies"
        }
      }
    ]
    volumeMounts = [
      {
        name      = var.download_pvc
        mountPath = "/downloads"
      },
      {
        name      = "media"
        mountPath = "/media"
      }
    ]
    config = {
      persistence = {
        size = var.config_size
      }
    }
    securityContext = {
      runAsUser = 1000
    }
    ingress = {
      annotations = {
        "cert-manager.io/cluster-issuer" = local.issuer,
        "external-dns.alpha.kubernetes.io/hostname" = local.fqdn,
      }
      enabled = true
      ingressClassName = "private"
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
