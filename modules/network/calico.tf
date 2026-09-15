
resource "helm_release" "calico" {
  namespace  = var.namespace
  name       = "calico"
  repository = "https://docs.tigera.io/calico/charts"
  chart      = "tigera-operator"
  wait       = true
  timeout    = 600
  values     = [yamlencode(local.helm_values.calico)]
  depends_on = [kubernetes_namespace_v1.namespace]
}

