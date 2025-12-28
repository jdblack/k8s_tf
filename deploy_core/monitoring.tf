resource kubernetes_namespace_v1 monitoring {
  metadata {
    name = "monitoring"
  }
}

module metrics_server {
  source = "../modules/monitoring/metrics_server"
  depends_on = [ module.prometheus ]
  namespace = "monitoring"
}

module smartctl {
  source = "../modules/monitoring/smartctl"
  depends_on = [ module.prometheus ]
  namespace = "monitoring"
}

module prometheus {
  source = "../modules/monitoring/prometheus"
  namespace = "monitoring"
  depends_on = [ module.network ]
  domain = var.deployment.common.domain
  cert_issuer = var.deployment.cert.cert_issuer

}

