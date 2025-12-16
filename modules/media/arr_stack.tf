
module radarr {
  source = "./radarr"
  namespace = var.namespace
  cert_issuers = var.cert_authorities
  #download_pvc = kubernetes_persistent_volume_claim.downloads.metadata[0].name
  download_pvc = "torrents"
  movies_pvc = "movies-archive"
}

module sonarr {
  source = "./sonarr"
  namespace = var.namespace
  cert_issuers = var.cert_authorities
  #download_pvc = kubernetes_persistent_volume_claim.downloads.metadata[0].name
  download_pvc = "torrents"
  movies_pvc = "movies-archive"
}

module prowlarr {
  source = "./prowlarr"
  namespace = var.namespace
  cert_issuers = var.cert_authorities
}

module bazarr {
  source = "./bazarr"
  namespace = var.namespace
  cert_issuers = var.cert_authorities
  movies_pvc = "movies-archive"
}
