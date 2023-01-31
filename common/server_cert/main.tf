locals {
  manifest = {
    apiVersion= "cert-manager.io/v1"
    kind= "Certificate"
    metadata = { 
      namespace = var.namespace
      name = var.name
    }
    spec = {
      secretName = var.name
      commonName = element(var.cert_domains,0)
      duration = "2160h" 
      renewBefore = "720h"
      privateKey = {
        keyAlgorithm = "RSA"
        encoding = var.encoding
      }

      usages = [ "server auth", "client auth"]
      dnsNames = var.cert_domains
      issuerRef = {
        name = var.issuer
        kind = "ClusterIssuer"
      }
    }
  }
}

resource "kubectl_manifest" "manifest" {
  yaml_body = yamlencode(local.manifest)
}

