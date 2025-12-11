variable namespace {}
variable name { default = "keycloak" }
variable adminuser { default = "admin" }
variable ingress_class { default  = "private" } 
variable domain {}
variable cert_issuer {}
variable credentials { default = "keycloak-credentials" }

variable helm_repo {  default="oci://registry-1.docker.io/cloudpirates" }
variable chart { default = "keycloak" }

locals {
  fqdn = "${var.name}.${var.domain}"
  url = "https://${local.fqdn}"
  helm_values = {
    keycloak = {
      adminuser = var.adminuser
      adminPassword = random_password.keycloak_admin.result
      proxyHeaders = "xforwarded"

    }
    ingress = {
      enabled = true
      className = "private"
      annotations = {
        "cert-manager.io/cluster-issuer" = var.cert_issuer,
        "external-dns.alpha.kubernetes.io/hostname" = local.fqdn,
      }
      hosts = [
        {
          host = local.fqdn
          paths = [
            {
              path     = "/"
              pathType = "Prefix"
            }
          ]
        }
      ]

      tls = [

        {
          hosts      = [local.fqdn]
          secretName = "cert-${local.fqdn}"
        }
      ]
      service = {
        type = "LoadBalancer"
      }

    }
  }
}
