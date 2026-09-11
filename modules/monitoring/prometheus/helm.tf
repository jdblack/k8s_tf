resource "helm_release" "prometheus" {
  name       = var.prometheus_name
  namespace  = var.namespace
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  values     = [yamlencode(local.helm_values)]

  # The Grafana pod mounts both of these. The configmap is already implied
  # (locals.tf references its name), but the secret is only referenced by name
  # *string* in the helm values -- no implicit edge -- so on a from-scratch build
  # tofu could apply the release first. This makes the order explicit: create
  # the files, then roll the pod that reads them.
  depends_on = [
    kubernetes_config_map_v1.grafana_ca,
    kubernetes_secret_v1.grafana_oidc,
  ]
}


