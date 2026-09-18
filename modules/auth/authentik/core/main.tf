resource "helm_release" "helm" {
  name       = var.name
  repository = "https://charts.goauthentik.io"
  chart      = "authentik"
  version    = var.helm_version
  namespace  = var.namespace
  wait       = true
  timeout    = 600
  values     = [yamlencode(local.helm_values)]
}
