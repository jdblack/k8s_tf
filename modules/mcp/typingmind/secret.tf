resource "kubernetes_secret_v1" "auth" {
  metadata {
    name      = "${var.name}-auth"
    namespace = var.namespace
    labels    = local.labels
  }

  data = {
    MCP_AUTH_TOKEN = var.auth_token
  }
}
