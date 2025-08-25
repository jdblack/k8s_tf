variable namespace { }
variable chart  { default = "https://argo-helm/charts/argo-cd" }
variable name { default = "argo" }
variable domain { type = string }
variable storage_size { default = "10Gi" }
variable ssl_ca { }
variable ssl_ca_namespace { }



variable devops_deploy_key { type = string } 
variable devops_deploy_repo { type = string }


locals {
  fqdn = "${var.name}.${var.domain}" 
  config = {
    global = { domain = local.fqdn }
    configs = {

      tls = {
        certificates = {
          "harbor.vn.linuxguru.net"= data.kubernetes_secret.ca_cert.data["tls.crt"]
          "keycloak.vn.linuxguru.net"= data.kubernetes_secret.ca_cert.data["tls.crt"]
        }
      }
    }

    server = {
      service = {
        type = "ClusterIP"
      }
      ingress = {
        enabled = true
        extraHosts = [
          { name = "argo"
          path = "/"
        }
      ]


      annotations = {
        "nginx.ingress.kubernetes.io/ssl-passthrough" : "true"
        "cert-manager.io/cluster-issuer" : var.ssl_ca
        "nginx.ingress.kubernetes.io/backend-protocol": "HTTPS"
      }
      ingressClassName = "private"

      rule = {
        hosts  = [
          var.name, 
          local.fqdn
        ]

        http = {
          path = {
            path = "/"
            path_type = "Prefix"  # Specify the path_type (Prefix or Exact)

            backend = {
              service = {
                name = var.name
                port = {
                  name= "https"
                }
              }
            }
          }
        }
      }

      tls = [
        {
          secretName = "cert-${local.fqdn}"
          hosts      = [local.fqdn, var.name]
        }
      ]
    }

  }
  persistence = {
    enabled       = true
    size          = var.storage_size
  }
  finalizers = [ "resources-finalizer.argocd.argoproj.io" ]
}
}
