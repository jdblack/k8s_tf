module "mcp" {
  source = "../../modules/mcp"

  # The browser calls the connector for every MCP tool call, so the private gateway is enough
  # -- no WAN exposure for a pod that runs the MCP servers it is handed.
  domain      = var.deployment.cluster.domains.private
  cert_issuer = var.deployment.cert_manager.external_issuer

  auth_token = var.deployment.mcp.auth_token
}
