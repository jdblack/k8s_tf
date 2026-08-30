resource "kubernetes_namespace_v1" "namespace" {
  count = var.create_namespace ? 1 : 0
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "wireguard_operator" {
  name       = "wireguard-operator"
  repository = "https://nccloud.github.io/charts"
  chart      = "wireguard-operator"
  version    = var.chart_version
  namespace  = var.namespace

  # Pinned chart + image (NOT "latest"): see the systemic unpinned-helm note in
  # TODO.md. Chart 0.3.0 ships the CRDs in crds/, so they exist before the
  # Wireguard/WireguardPeer manifests below are applied.
  values = [yamlencode({
    nameOverride = "wireguard-operator"
    image = {
      tag        = var.image_tag
      pullPolicy = "IfNotPresent"
    }
  })]

  depends_on = [kubernetes_namespace_v1.namespace]
}

locals {
  wg_spec = {
    mtu                      = "1380"
    enableIpForwardOnPodInit = true
    serviceType              = "LoadBalancer"
    dns                      = var.dns != "" ? var.dns : null
    dnsSearchDomain          = length(var.dns_search_domains) > 0 ? join(", ", var.dns_search_domains) : null
    externalAddress          = var.external_address != "" ? var.external_address : null
  }
}

resource "kubectl_manifest" "wireguard_server" {
  depends_on = [helm_release.wireguard_operator]
  yaml_body = yamlencode({
    apiVersion = "vpn.wireguard-operator.io/v1alpha1"
    kind       = "Wireguard"
    metadata = {
      name      = var.wireguard_name
      namespace = var.namespace
    }
    spec = local.wg_spec
  })
}

resource "kubectl_manifest" "wireguard_peers" {
  for_each = toset(var.peers)

  depends_on = [kubectl_manifest.wireguard_server]
  yaml_body = yamlencode({
    apiVersion = "vpn.wireguard-operator.io/v1alpha1"
    kind       = "WireguardPeer"
    metadata = {
      name      = each.key
      namespace = var.namespace
    }
    spec = {
      wireguardRef = var.wireguard_name
    }
  })
}
