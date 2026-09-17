# NGF's data-plane label, spelled once for the three calls that need to reach it.
locals {
  gateway_peer = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = 443 }]
  }]
}
