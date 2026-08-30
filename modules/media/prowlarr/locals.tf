locals {
  fqdn      = "${var.name}.${var.domain}"
  cert_name = "cert-${var.name}.${var.domain}"

  # prowlarr kept its old user-supplied ingress values after the ingress block
  # was removed (an empty values map doesn't reset a release's prior values),
  # so pin it off explicitly. The old Ingress goes away on the next upgrade.
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

