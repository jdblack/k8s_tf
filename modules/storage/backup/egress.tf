module "egress" {
  source    = "../../network/firewalls/policy"
  direction = "egress"

  namespace     = kubernetes_namespace_v1.namespace.metadata[0].name
  name          = "velero-egress"
  allow_k8s_api = true

  # The server and node-agent both upload to the S3 endpoint, which is the gateway hostname.
  peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = 443 }]
  }]
}
