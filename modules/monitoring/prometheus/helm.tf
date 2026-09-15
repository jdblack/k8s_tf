# Chart version is pinned deliberately: the chart version and the bundled CRDs' are
# not the same version line (see the crds/upgradeJob note in locals.tf), so bump on
# purpose, one version at a time, reading the changelog for CRD/values breakage.
resource "helm_release" "prometheus" {
  name       = var.prometheus_name
  namespace  = var.namespace
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.helm_version
  wait       = true
  timeout    = 600
  values     = [yamlencode(local.helm_values)]

  # Grafana reads the OIDC client credentials from a file at startup, so the secret
  # must exist before the pod that mounts it.
  depends_on = [
    kubernetes_secret_v1.grafana_oidc,
  ]
}

