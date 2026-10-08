module "egress" {
  source    = "../../network/firewalls/policy"
  direction = "egress"

  namespace     = kubernetes_namespace_v1.namespace.metadata[0].name
  name          = "velero-egress"
  allow_k8s_api = true

  # Every backup goes to the local S3 via the gateway hostname; nothing leaves for the internet.
  allow_internet = false
  peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = 443 }]
  }]
}
