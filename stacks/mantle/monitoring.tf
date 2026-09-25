module "grafana_oidc" {
  source    = "../../modules/monitoring/grafana_oidc"
  namespace = "monitoring"
  domain    = var.deployment.cluster.domains.private
}

# Alertmanager's own UI, so silence links in notifications resolve from a phone.
module "alertmanager" {
  source = "../../modules/monitoring/alertmanager"

  namespace   = "monitoring"
  domain      = var.deployment.cluster.domains.private
  cert_issuer = var.deployment.cert_manager.external_issuer
}
