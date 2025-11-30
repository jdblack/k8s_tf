resource helm_release plex {
  name  = "plex"
  repository = "https://raw.githubusercontent.com/plexinc/pms-docker/gh-pages"
  chart = "plex-media-server"
  version = var.chart_version
  namespace = var.namespace
  values = [yamlencode(local.plex_helm_values)]
}


