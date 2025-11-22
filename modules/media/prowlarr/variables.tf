variable namespace { type = string }
variable cert_issuers { type = map }
variable name { default = "prowlarr" }
variable config_size { default = "1Gi" }
variable helm_repo { default = "https://charts.pree.dev" }
variable chart { default = "prowlarr" }
variable visibility { default = "private" }

locals {
  sub = var.visibility == "private" ? ".vn" : "" 
  fqdn = "${var.name}${local.sub}.linuxguru.net"
  issuer = var.cert_issuers[var.visibility]

  helm_values = {
    ingress = {
      main = { 
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
}
