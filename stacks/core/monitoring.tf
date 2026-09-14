resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

module "metrics_server" {
  source     = "../../modules/monitoring/metrics_server"
  depends_on = [module.prometheus]
  namespace  = "monitoring"
}

module "smartctl" {
  source     = "../../modules/monitoring/smartctl"
  depends_on = [module.prometheus]
  namespace  = "monitoring"
}

module "prometheus" {
  source    = "../../modules/monitoring/prometheus"
  namespace = "monitoring"
  # module.storage: this module creates Grafana/Prometheus/Alertmanager PVCs on
  # Longhorn, so the module that installs Longhorn has to be applied first.
  depends_on = [
    module.network,
    module.cert_man,
    module.storage,
  ]
  domain = var.deployment.common.domain
  # Leaf cert only. Grafana's OIDC client trusts authentik through the
  # container's public roots, so it mounts no CA bundle.
  cert_issuer = var.deployment.cert_authorities.public
}

