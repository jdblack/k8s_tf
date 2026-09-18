module "ingress_longhorn_system" {
  source = "../network/firewalls/ingress"

  namespace = var.longhorn_namespace
  name      = "longhorn-system-ingress"
}

module "ingress_longhorn_manager_metrics" {
  source = "../network/firewalls/ingress"

  namespace = var.longhorn_namespace
  name      = "longhorn-manager-metrics-ingress"

  pod_selector    = { "app" = "longhorn-manager" }
  allow_namespace = false
  allow_nodes     = false

  from_peers = [
    {
      namespace    = var.monitoring_namespace
      pod_selector = { "app.kubernetes.io/name" = "prometheus" }
      ports        = [{ port = 9500 }]
    },
  ]
}
