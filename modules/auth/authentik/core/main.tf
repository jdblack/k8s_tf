


resource "helm_release" "helm" {
  name       = var.name
  repository = "https://charts.goauthentik.io"
  chart      = "authentik"
  # Pinned: 2026.8.0 (unpinned latest) crashes at startup in this cluster
  # ("server has exited unexpectedly"). Upgrade deliberately later.
  version   = var.helm_version
  namespace = var.namespace
  wait      = true
  timeout   = 600
  values    = [yamlencode(local.helm_values)]
}


