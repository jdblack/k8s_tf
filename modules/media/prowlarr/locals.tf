locals {
  fqdn = "${var.name}.${var.domain}"

  helm_values = {
    ingress = {
      annotations = {
        "cert-manager.io/cluster-issuer"            = var.cert_issuer,
        "external-dns.alpha.kubernetes.io/hostname" = local.fqdn,
      }
      enabled          = true
      ingressClassName = var.ingress_class
      url              = local.fqdn

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
