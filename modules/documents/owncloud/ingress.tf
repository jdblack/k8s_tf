module "ingress_gateway" {
  source    = "../../network/firewalls/policy"
  direction = "ingress"

  namespace = var.namespace
  name      = "owncloud-gateway-ingress"

  peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = var.proxy_port }]
  }]
}

# The chart's ServiceMonitor scrapes a metrics-debug port on thirty-odd services, so
# naming each would be churn. Prometheus is a trusted peer and the namespace holds
# nothing but oCIS, so it gets the pods rather than a port list.
module "ingress_metrics" {
  count     = var.metrics_enabled ? 1 : 0
  source    = "../../network/firewalls/policy"
  direction = "ingress"

  namespace = var.namespace
  name      = "owncloud-metrics-ingress"

  peers = [{
    namespace    = var.monitoring_namespace
    pod_selector = { "app.kubernetes.io/name" = "prometheus" }
    ports        = []
  }]
}
