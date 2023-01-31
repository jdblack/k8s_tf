locals {
  issuer_manifest = {
    apiVersion= "cert-manager.io/v1"
    kind= "ClusterIssuer"
    metadata = {
      name= var.issuer_name
      namespace = var.namespace
    }
    spec = {
      ca = {
        secretName = var.issuer_name
      }
    }
  }
}

resource "kubectl_manifest" "issuer" {
  yaml_body = yamlencode(local.issuer_manifest)
  depends_on =  [ helm_release.release] 
}

resource "kubernetes_secret" "ca-key"  {
  type="kubernetes.io/tls"
  depends_on  = [ kubernetes_namespace.namespace ]
  metadata {
    namespace = var.namespace
    name = var.issuer_name
  }
  data = {
    "tls.crt" = file(var.ca_certfile)
    "tls.key" = file(var.ca_keyfile)
  }
}



