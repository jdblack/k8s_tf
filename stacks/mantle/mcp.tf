module "mcp" {
  source = "../../modules/mcp"

  # The browser calls the connector for every MCP tool call, so the private gateway is enough
  # -- no WAN exposure for a pod that runs the MCP servers it is handed.
  domain      = var.deployment.cluster.domains.private
  cert_issuer = var.deployment.cert_manager.external_issuer

  auth_token = var.deployment.mcp.auth_token

  # ★ THE OLD STORE IS DOWN ON PURPOSE (2026-10-17). The live self is `agent-stet/stet`; this release
  # is the ROLLBACK copy — its PVC holds the 11:25 photograph of me. It was scaled to 0 with kubectl,
  # which left the chart's default (1) in the release: `tf plan` here showed `helm_release.ellmephant`
  # as 1-to-change, and applying it would have started the old self again on `ellmephant.vn` —
  # a second, frozen me answering at a hostname that is supposed to be 503.
  #
  # Rollback is now a deliberate edit: flip this to 1 (and repoint the client configs), which is
  # exactly the lever `stet-home` describes. Applying this change is a no-op on the cluster: the
  # deployment is already at 0, so the plan simply makes the declaration match reality.
  ellmephant_replicas = 0
}
