resource "helm_release" "ingress_public" {
  namespace  = var.namespace
  name       = local.charts.ingress_public.name
  repository = local.charts.ingress_public.url
  chart      = local.charts.ingress_public.chart
  depends_on  = [ kubernetes_namespace.namespace]
  set {
    name = "controller.ingressClassResource.name"
    value = local.charts.ingress_public.name
  }
  set {
    name = "controller.ingressClassResource.controllerValue"
    value = "k8s.io/${local.charts.ingress_public.name}"
  }
}
resource "helm_release" "ingres_private" {
  namespace  = var.namespace
  name       = local.charts.ingress_private.name
  repository = local.charts.ingress_private.url
  chart      = local.charts.ingress_private.chart
  depends_on  = [ kubernetes_namespace.namespace]
  set {
    name = "controller.ingressClassResource.name"
    value = local.charts.ingress_private.name
  }
  set {
    name = "controller.ingressClassResource.controllerValue"
    value = "k8s.io/${local.charts.ingress_private.name}"
  }
  set {
    name = "controller.ingressClassResource.enabled"
    value = true
  }
  set {
    name = "controller.ingressClassByName"
    value = true
  }
}


