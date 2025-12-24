variable namespace {}
variable name { default = "authentik" }
variable ingress_class { default  = "private" } 
variable domain {}
variable cert_issuer {}
variable fqdn { default = "" }

locals {
  fqdn = coalesce(var.fqdn, "${var.name}.${var.domain}")
  helm_values = {
    global = {
      volumeMounts = [
        {
          name = "cert"
          mountPath = "/certs/${var.fqdn}"
        }
      ]
      volumes = [
        {
          name = "cert"
          secret = {
            secretName = "cert-${local.fqdn}"
          }
        }
      ]
    }
    blueprints = {
      secrets = [
        kubernetes_secret_v1.blueprint_deploy_key.metadata[0].name
      ]
    }
    authentik = {
      secret_key = random_password.cookie_token.result
      postgresql = {
        password = random_password.postgres_pass.result
      }
    },
    postgresql = {
      enabled = true
      auth = {
        password = random_password.postgres_pass.result
      }
    }
    server = { 
      ingress = {
        enabled = true
        ingressClassName = var.ingress_class
        annotations = {
          "cert-manager.io/cluster-issuer" = var.cert_issuer,
          "external-dns.alpha.kubernetes.io/hostname" = local.fqdn,
        }
        hosts = [ local.fqdn ]

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
}
