resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

module "metrics_server" {
  source     = "../../modules/monitoring/metrics_server"
  depends_on = [module.prometheus]
  namespace  = "monitoring"
}

module "smartctl" {
  source     = "../../modules/monitoring/smartctl"
  depends_on = [module.prometheus]
  namespace  = "monitoring"
}

module "prometheus" {
  source    = "../../modules/monitoring/prometheus"
  namespace = "monitoring"
  depends_on = [
    module.network,
    module.cert_man,
    module.storage,
  ]
  domain      = var.deployment.cluster.domains.private
  cert_issuer = var.deployment.cert_manager.external_issuer

  # Absent keys leave Alertmanager on its silent default receiver.
  pushover_user_key     = try(var.deployment.monitoring.pushover.user_key, "")
  pushover_token        = try(var.deployment.monitoring.pushover.token, "")
  slack_webhook_routine = try(var.deployment.monitoring.slack.webhook_routine, "")
  slack_webhook_mirror  = try(var.deployment.monitoring.slack.webhook_mirror, "")
}
