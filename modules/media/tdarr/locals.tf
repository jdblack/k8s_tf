locals {
  fqdn = "${var.name}.${var.domain}"

  image = {
    repository = "ghcr.io/haveagitgat/tdarr"
    tag = "2.58.02"
  }
  node = {
    image = {
      repository = "ghcr.io/haveagitgat/tdarr_node"
      tag = "2.58.02"
    }
  }
  volumes = [
    {
      name = "media"
      persistentVolumeClaim = {
        claimName = var.movies_pvc
      }
    }
  ]
  volumeMounts = [
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
  ingress =  {
    main = {
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
