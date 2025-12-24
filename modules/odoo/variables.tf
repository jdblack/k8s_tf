variable namespace { type = string }
variable cert_authority { type = string }
variable domain { type = string }

variable name { default = "odoo" }
variable config_size { default = "1Gi" }
variable helm_repo { default = "oci://registry-1.docker.io/ptnglobalcorp" }
variable chart { default = "odoo" }
variable visibility { default = "private" }

locals {
  fqdn = "${var.name}.${var.domain}"
  issuer = var.cert_authority

  helm_values = {
    image = {
      registry = "ghcr.io"
      repository = "adomi-io/odoo"
      tag = "19.0"
    }
    ingress = {
      annotations = {
        "cert-manager.io/cluster-issuer" = local.issuer,
        "external-dns.alpha.kubernetes.io/hostname" = local.fqdn,
      }
      enabled = true
      ingressClassName = var.visibility
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
