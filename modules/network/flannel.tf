locals {
  flannel_config = {
  }

}

resource "helm_release" "flannel" {
  namespace  = var.namespace
  name       = local.charts.flannel.name
  repository = local.charts.flannel.url
  chart      = local.charts.flannel.chart
  values = [yamlencode(local.flannel_config)]
  depends_on  = [ kubernetes_namespace.namespace]
}

