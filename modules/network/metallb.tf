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
  version    = "0.16.1" # bumped from 0.15.3 on 2026-08-29
  # BGP backend: NATIVE mode (frr disabled, frrk8s disabled). This cluster is
  # L2-only (single IPAddressPool, no BGPPeers), so native is the smallest
  # correct footprint: single-container speaker, no idle FRR sidecars, no
  # frr-k8s controller/CRDs. 0.16.0 deprecated FRR mode in favor of frr-k8s;
  # if BGP is ever needed, switch to frrk8s.enabled = true (the chart default).
  values = [yamlencode({
    speaker = {
      frr = {
        enabled = false
      }
    }
    frrk8s = {
      enabled = false
    }
  })]
  # Note: no loadBalancerClass is set here. MetalLB serves ALL LoadBalancer
  # services, which is the desired behavior for this cluster (MetalLB is the
  # only LB implementation). The previous `set { name = "spec.loadBalancerClass" }`
  # was a no-op (the chart value is the top-level `loadBalancerClass`) and has
  # been removed. If a second LB controller is ever added, revisit this and set
  # `loadBalancerClass` + add the class to every Service that MetalLB should serve.
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
