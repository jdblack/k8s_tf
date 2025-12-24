locals {
  issuer_name = var.data["cert_issuer"]
  issuer_manifest = {
    apiVersion= "cert-manager.io/v1"
    kind= "ClusterIssuer"
    metadata = {
      name= local.issuer_name
      namespace = var.namespace
    }
    spec = {
      ca = {
        secretName = local.issuer_name
      }
    }
  }
}

resource "kubectl_manifest" "issuer" {
  yaml_body = yamlencode(local.issuer_manifest)
  depends_on =  [ helm_release.release] 
}

resource kubernetes_secret_v1 "ca-key"  {
  type="kubernetes.io/tls"
  depends_on  = [ kubernetes_namespace_v1.namespace ]
  metadata {
    namespace = var.namespace
    name = local.issuer_name
  }
  data = {
    "tls.crt" = file(var.ca_certfile)
    "tls.key" = file(var.ca_keyfile)
  }
}



