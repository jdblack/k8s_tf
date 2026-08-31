


resource "helm_release" "helm" {
  name       = var.name
  repository = "https://charts.goauthentik.io"
  chart      = "authentik"
  # Pinned: 2026.8.0 (unpinned latest) crashes at startup in this cluster
  # ("server has exited unexpectedly"). Upgrade deliberately later.
  version   = "2025.10.3"
  namespace = var.namespace
  values    = [yamlencode(local.helm_values)]
}


