module "ingress" {
  source = "../network/firewalls/ingress"

  namespace = kubernetes_namespace_v1.this.metadata[0].name
  name      = "documents-ingress"

  # The route's own gateway; in-namespace traffic (app to broker, app to ollama) is the default.
  from_peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = local.app_port }]
  }]
}
