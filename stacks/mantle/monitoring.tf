module "grafana_oidc" {
  source    = "../../modules/monitoring/grafana_oidc"
  namespace = "monitoring"
  domain    = var.deployment.common.domain
}
