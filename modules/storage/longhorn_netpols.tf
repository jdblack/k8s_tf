module "ingress_longhorn_system" {
  source    = "../network/firewalls/policy"
  direction = "ingress"

  namespace = var.longhorn_namespace
  name      = "longhorn-system-ingress"

  peers = [
    {
      namespace    = var.monitoring_namespace
      pod_selector = { "app.kubernetes.io/name" = "prometheus" }
      ports        = [{ port = 9500 }]
    },
  ]
}
