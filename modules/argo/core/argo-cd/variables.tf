
variable namespace { type = string }
variable name { default = "argo-cd" }
variable domain { type = string }
variable cert_issuer { type = string } 
variable storage_size { default = "10Gi" }

variable repo { default = "https://argoproj.github.io/argo-helm" }
variable chart { default = "argo-cd" }


locals {
  fqdn = "${var.name}.${var.domain}" 
  config = {
    global = { domain = local.fqdn }
    configs = {
      rbac = {
        "policy.csv" = <<-EOF
        g, argocd-admin, role:readonly
        g, argocd-user, role:readonly
        EOF
      }
    }

    server = {
      service = {
        type = "ClusterIP"
      }

      ingress = {
        ingressClassName = "private"
        enabled = true
        extraHosts = [
          {
            name = var.name
            path = "/"
          }
        ]

        annotations = {
          "nginx.ingress.kubernetes.io/ssl-passthrough" : "true"
          "cert-manager.io/cluster-issuer" : var.cert_issuer
          "nginx.ingress.kubernetes.io/backend-protocol": "HTTPS"
        }

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
#      persistence = {
#        enabled       = true
#        size          = var.storage_size
#      }
    }

    finalizers = [ "resources-finalizer.argocd.argoproj.io" ]
  }
}
