
data kubernetes_secret_v1 ca_cert {
  metadata {
    name      = var.ssl_ca
    namespace = var.ssl_ca_namespace
  }
}

resource kubernetes_config_map_v1 argocd_ca_cert {
  metadata {
    name = "${var.ssl_ca}.crt"
    namespace = var.namespace
  }
  data = {
    "ca.crt"= data.kubernetes_secret_v1.ca_cert.data["tls.crt"]
  }
  depends_on = [  kubernetes_namespace_v1.argocd ]
}

resource kubernetes_config_map_v1_data argocd_tls_cert {
  metadata {
    name      = "argocd-tls-certs-cm"
    namespace = var.namespace
  }

  data = {
    "harbor.vn.linuxguru.net"= data.kubernetes_secret_v1.ca_cert.data["tls.crt"]
  }
  depends_on = [  helm_release.argocd ] 
}

