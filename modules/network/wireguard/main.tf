resource "helm_release" "wireguard_operator" {
  name       = "wireguard-operator"
  repository = "https://nccloud.github.io/charts"
  chart      = "wireguard-operator"
  version    = var.helm_version
  namespace  = var.namespace

  wait    = true
  timeout = 600
  values  = [yamlencode(local.helm_values)]

  depends_on = [kubernetes_namespace_v1.namespace]
}
