
variable namespace { type = string }
variable name { default = "argo-workflows" }
variable domain { type = string }
variable cert_issuer { type = string } 

variable repo { default = "https://argoproj.github.io/argo-helm" }
variable chart { default = "argo-workflows" }

locals {
  fqdn = "${var.name}.${var.domain}" 
  config = {
    server = {
      service = {
        type = "ClusterIP"
      }

      ingress = {
        ingressClassName = var.cert_issuer
        enabled = true
        hosts = [ var.name, local.fqdn ]
        annotations = {
          "cert-manager.io/cluster-issuer" : var.cert_issuer
        }

        tls = [
          {
            secretName = "cert-${local.fqdn}"
            hosts      = [local.fqdn, var.name]
          }
        ]
      }
    }
  }
}
