

module radarr {
  source = "./radarr"
  namespace = var.namespace
  cert_issuer = local.local_issuer
  domain = local.local_domain
  ingress_class = local.private_ingress_name
  movies_pvc = local.movies_pvc
}

module tdarr {
  source = "./tdarr"
  count = 0
  namespace = var.namespace
  cert_issuer = local.local_issuer
  domain = local.local_domain
  ingress_class = local.private_ingress_name
  movies_pvc = local.movies_pvc
}

module sonarr {
  source = "./sonarr"
  namespace = var.namespace
  cert_issuer = local.local_issuer
  domain = local.local_domain
  ingress_class = local.private_ingress_name
  movies_pvc = local.movies_pvc
}

module prowlarr {
  source = "./prowlarr"
  namespace = var.namespace
  cert_issuer = local.local_issuer
  ingress_class = local.private_ingress_name
  domain = local.local_domain
}

module bazarr {
  source = "./bazarr"
  namespace = var.namespace
  cert_issuer = local.local_issuer
  ingress_class = local.private_ingress_name
  domain = local.local_domain
  movies_pvc = local.movies_pvc
}

module transmission {
  source = "./transmission"
  count = 0
  namespace = var.namespace
  cert_issuer = local.local_issuer
  ingress_class = local.private_ingress_name
  domain = local.local_domain
  movies_pvc = local.movies_pvc
}

module qbittorrent {
  source = "./qbittorrent"
  namespace = var.namespace
  cert_issuer = local.local_issuer
  ingress_class = local.private_ingress_name
  domain = local.local_domain
  movies_pvc = local.movies_pvc
}

