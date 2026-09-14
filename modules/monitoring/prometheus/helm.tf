# Chart version is pinned deliberately: unpinned, this release rode chart
# 82 -> 90 unattended and left the CRDs nine operator releases behind (see the
# crds/upgradeJob note in locals.tf). Bump on purpose, one version at a time,
# reading the changelog for CRD/values breakage.
resource "helm_release" "prometheus" {
  name       = var.prometheus_name
  namespace  = var.namespace
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "90.1.1"
  values     = [yamlencode(local.helm_values)]

  # The Grafana pod mounts both. The configmap is implied by name in
  # locals.tf; the secret is only a string in the helm values, so make the
  # order explicit: create the files, then roll the pod that reads them.
  depends_on = [
    kubernetes_config_map_v1.grafana_ca,
    kubernetes_secret_v1.grafana_oidc,
  ]
}


