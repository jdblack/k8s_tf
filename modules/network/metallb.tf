locals {
  pool_name = "default"

  pool_manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "IPAddressPool"
    metadata = {
      name      = local.pool_name
      namespace = var.namespace
    }
    spec = {
      addresses = [var.metal_networks]
    }
  }

  advertise_manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "L2Advertisement"
    metadata = {
      name      = "l2advertise"
      namespace = var.namespace
    }
    spec = {
      ipAddressPools = [local.pool_name]
    }
  }
}

resource "helm_release" "metal" {
  namespace  = var.namespace
  name       = local.charts.metal.name
  repository = local.charts.metal.url
  chart      = local.charts.metal.chart
  version    = var.helm_metallb_version
  wait       = true
  timeout    = 600
  values     = [yamlencode(local.helm_values.metallb)]
  # No loadBalancerClass on purpose: MetalLB is the only LB implementation here. It belongs at the
  # chart's top level and on any Service MetalLB should serve, so revisit if a second controller
  # is ever added.
  depends_on = [kubernetes_namespace_v1.namespace]
}

resource "kubectl_manifest" "addresspool" {
  depends_on = [helm_release.metal]
  yaml_body  = yamlencode(local.pool_manifest)
}

resource "kubectl_manifest" "advertise" {
  depends_on = [helm_release.metal]
  yaml_body  = yamlencode(local.advertise_manifest)
}
