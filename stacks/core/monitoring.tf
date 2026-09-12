resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

module "ntfy" {
  source      = "../../modules/monitoring/ntfy"
  namespace   = "monitoring"
  domain      = var.deployment.domains.public
  cert_issuer = var.deployment.cert_authorities.public

  # network  : the Gateway API CRDs (the ListenerSet/HTTPRoute are planned with
  #            kubernetes_manifest, so the CRDs must exist at plan time).
  # cert_man : the letsencrypt ClusterIssuer the ListenerSet is annotated with.
  # storage  : ntfy has a Longhorn PVC. Without this edge a from-scratch build
  #            can hang -- PVC Pending -> pod Pending -> helm waits -> and
  #            because module.prometheus depends on this module, everything
  #            downstream (prometheus, metrics-server, smartctl) blocks too.
  #            Same reasoning as authentik/harbor's depends_on module.storage.
  depends_on = [
    kubernetes_namespace_v1.monitoring,
    module.network,
    module.cert_man,
    module.storage,
  ]
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
  # cert_man owns the private CA ConfigMap the module mirrors into `monitoring`
  # for Grafana's OIDC client; the data source needs it applied first.
  #
  # module.storage is the drive-by fix for a latent hole: this module creates
  # Grafana/Prometheus/Alertmanager PVCs on Longhorn but never depended on the
  # module that installs it. module.ntfy -> module.storage transitively covered
  # it, so state it explicitly instead of relying on that.
  #
  # module.ntfy supplies the Alertmanager receiver: its publish token Secret and
  # the endpoint. One direction only (prometheus -> ntfy) -- ntfy must never
  # depend on prometheus, which is why the ntfy ServiceMonitor lives here.
  depends_on = [
    module.network,
    module.cert_man,
    module.storage,
    module.ntfy,
  ]
  domain      = var.deployment.common.domain
  cert_issuer = var.deployment.cert.cert_issuer

  ntfy = {
    url               = module.ntfy.publish_url
    token_secret_name = module.ntfy.token_secret_name
    token_secret_key  = module.ntfy.token_secret_key
  }
}

# ntfy (alert notifications). The admin password is the break-glass way into the
# web UI: the UI cannot create an admin and the admin API cannot create the
# first one, so this is the only path in besides `kubectl exec`.
#
#   tofu -chdir=stacks/core output -raw ntfy_admin_password
#
# Human users' passwords live in the `ntfy-users` Secret (created by the mantle
# stack), not here.
output "ntfy_url" {
  value = "https://${module.ntfy.fqdn}"
}

output "ntfy_admin_user" {
  value = module.ntfy.admin_user
}

output "ntfy_admin_password" {
  value     = module.ntfy.admin_password
  sensitive = true
}

