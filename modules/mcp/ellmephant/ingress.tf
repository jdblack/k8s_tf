# Admit the gateway on the MCP port. Same-namespace callers (the TypingMind connector) are already
# covered by the namespace's baseline ingress policy.
module "ingress" {
  source    = "../../network/firewalls/policy"
  direction = "ingress"

  namespace    = var.namespace
  name         = "${var.name}-ingress"
  pod_selector = local.selector_labels

  peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = var.mcp_port }]
  }]
}
