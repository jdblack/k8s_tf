# The gateway data plane has to reach the proxy, and the kubelet its probes. Egress needs no
# policy of its own: the namespace baseline already admits self and DNS, which covers the
# authentik server the proxy forwards to.
module "ingress_gateway" {
  source    = "../../../network/firewalls/policy"
  direction = "ingress"

  namespace    = var.namespace
  name         = "${var.name}-ingress"
  pod_selector = local.labels

  peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = local.port }]
  }]
}
