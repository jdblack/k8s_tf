# Please see https://metallb.universe.tf/installation/ about IPVS

locals {
  pool_manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind =  "IPAddressPool"
    metadata = {
      name = "default"
      namespace= var.namespace
    }
    spec = {
      addresses = [var.deployment.metal.networks]
    }
  }
  advertise_manifest = {
    apiVersion= "metallb.io/v1beta1"
    kind= "L2Advertisement"
    metadata = {
      name = "l2advertise"
      namespace= var.namespace
    }
    ipAddressPools = ["default"]

  }
}

resource "helm_release" "metal" {
  namespace  = var.namespace
  name       = local.charts.metal.name
  repository = local.charts.metal.url
  chart      = local.charts.metal.chart
  set = [ {
    name = "spec.loadBalancerClass"
    value = "metallb"
  } ] 
  depends_on  = [ kubernetes_namespace.namespace]
}

resource "kubectl_manifest" "addresspool" {
  depends_on = [ helm_release.metal ]
  yaml_body = yamlencode(local.pool_manifest)
}

resource "kubectl_manifest" "advertise" {
  depends_on = [ helm_release.metal ]
  yaml_body = yamlencode(local.advertise_manifest)
}
