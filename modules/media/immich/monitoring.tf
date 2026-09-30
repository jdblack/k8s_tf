module "ingress_metrics" {
  count     = var.metrics_enabled ? 1 : 0
  source    = "../../network/firewalls/policy"
  direction = "ingress"

  namespace = var.namespace
  name      = "${var.name}-metrics-ingress"

  pod_selector = {
    "app.kubernetes.io/instance" = var.name
    "app.kubernetes.io/name"     = "server"
  }

  peers = [{
    namespace    = var.monitoring_namespace
    pod_selector = { "app.kubernetes.io/name" = "prometheus" }
    ports        = [{ port = 8081 }, { port = 8082 }]
  }]
}
