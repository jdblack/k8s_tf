
module transmission {
  source = "./transmission"
  namespace = var.namespace
  cert_issuers = var.cert_authorities

  download_pvc = kubernetes_persistent_volume_claim.downloads.metadata[0].name
}

