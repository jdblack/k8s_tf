
data kubernetes_config_map_v1 ca_cert {
  metadata {
    name      = var.cert_issuer
  }
}

resource kubernetes_config_map_v1_data argocd_tls_cert {
  metadata {
    name      = "argocd-tls-certs-cm"
    namespace = var.namespace
  }

  data = {
    "harbor.vn.linuxguru.net"= data.kubernetes_config_map_v1.ca_cert.data["tls.crt"]
  }
  depends_on = [  helm_release.argocd ]
}
