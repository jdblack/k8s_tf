locals {
  data_plane_name = "${var.gateway_name}-${var.gateway_name}"
}

module "ingress_baseline" {
  source    = "../network/firewalls/policy"
  direction = "ingress"

  namespace = var.namespace
  name      = "media-ingress"

  pod_selector_expressions = [{
    key      = "app.kubernetes.io/name"
    operator = "NotIn"
    values   = ["plex-media-server", "qbittorrent", local.data_plane_name]
  }]
}
