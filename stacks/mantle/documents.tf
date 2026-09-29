module "documents" {
  source = "../../modules/documents"

  domain      = var.deployment.cluster.domains.private
  cert_issuer = var.deployment.cert_manager.external_issuer

  hostname = "docs.${var.deployment.cluster.domains.private}"

  image_tag = "3.2.1"

  # The module would guess paperless.svg; this is the current logo.
  icon = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/paperless-ngx.svg"

  # Phase 4: the AI backend, its own ollama in this namespace.
  enable_ai = true
}
