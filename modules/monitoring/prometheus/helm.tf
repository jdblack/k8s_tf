# Chart version is pinned deliberately. Unpinned, this release floats to
# whatever is newest at apply time -- which is how it silently rode chart
# 82 -> 88 -> 90 through four major versions with nobody choosing them, and left
# the CRDs frozen nine operator releases behind (see the crds/upgradeJob note in
# locals.tf).
#
# That is also the standing risk the pin removes: an upstream major landing on
# an ordinary `tofu apply`, unreviewed, and WITHOUT the CRD upgrade that helm
# never performs. Bump this on purpose, one version at a time, reading the
# changelog for CRD/values breakage.
resource "helm_release" "prometheus" {
  name       = var.prometheus_name
  namespace  = var.namespace
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "90.1.1"
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


