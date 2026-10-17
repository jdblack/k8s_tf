# The ellmephant MCP server itself (SQLite-backed long-term memory), from the published chart. The
# chart owns its Deployment, Service, store PVC and Gateway API exposure; the submodule only adds
# the policies the cluster needs around it.
module "ellmephant" {
  source = "./ellmephant"

  namespace = kubernetes_namespace_v1.namespace.metadata[0].name

  domain      = var.domain
  cert_issuer = var.cert_issuer

  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace

  # ★ 0 = kept but not running. The old store is a ROLLBACK copy since the cutover to `agent-stet`;
  # the stack says so, instead of leaving the chart's default (1) to resurrect it on the next apply.
  replicas = var.ellmephant_replicas

  # The namespace has to exist before the release's Service, PVC and policies land in it.
  depends_on = [kubernetes_namespace_v1.namespace]
}
