# Grafana SSO: the authentik OIDC client and the credential secret the grafana release
# (core stack) reads.
module "grafana_oidc" {
  source    = "../../modules/monitoring/grafana_oidc"
  namespace = "monitoring"
  domain    = var.deployment.common.domain
}

