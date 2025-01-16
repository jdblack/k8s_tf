
variable name      { default= "external-secrets" }
variable helm_repo { default = "https://charts.external-secrets.io" }
variable chart     { default = "external-secrets" }
variable namespace { default = "kube-secrets" } 
variable cert_issuer { default="linuxguru-ca" }
variable namespace_create { default = true }

resource  kubernetes_namespace namespace {
  metadata {
    name = var.namespace
  }
  count = var.namespace_create ? 1 : 0
}


locals {
  config = {
    webhook = { 
    certManager = {
      enabled = true
      cert = {
        issuerRef = {
          group = "cert-manager.io"
          kind = "ClusterIssuer"
          name = var.cert_issuer
        }
      }
    }
  }
}
}

resource helm_release release {
  name  = var.name
  repository = var.helm_repo
  chart = var.chart
  namespace = var.namespace
  #  values =  [yamlencode(local.config)]
  depends_on = [ kubernetes_namespace.namespace ]
}

