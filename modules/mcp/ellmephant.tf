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

  # The namespace has to exist before the release's Service, PVC and policies land in it.
  depends_on = [kubernetes_namespace_v1.namespace]
}
