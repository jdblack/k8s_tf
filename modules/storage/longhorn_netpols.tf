module "ingress_longhorn_system" {
  source = "../network/firewalls/ingress"

  namespace = var.longhorn_namespace
  name      = "longhorn-system-ingress"

  from_peers = [
    {
      namespace    = var.monitoring_namespace
      pod_selector = { "app.kubernetes.io/name" = "prometheus" }
      ports        = [{ port = 9500 }]
    },
  ]
}
