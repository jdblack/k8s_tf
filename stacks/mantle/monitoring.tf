# Grafana SSO. The grafana release itself is managed by the core stack; this
# only creates the authentik OIDC client and the credential secret it reads.
module "grafana_oidc" {
  source    = "../../modules/monitoring/grafana_oidc"
  namespace = "monitoring"
  domain    = var.deployment.common.domain
}
