locals {
  flannel_config = {
  }

}

resource "helm_release" "flannel" {
  count = 0
  namespace  = var.namespace
  name       = local.charts.flannel.name
  repository = local.charts.flannel.url
  chart      = local.charts.flannel.chart
  values = [yamlencode(local.flannel_config)]
  depends_on  = [ kubernetes_namespace.namespace]
}

