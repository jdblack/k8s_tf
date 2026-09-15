resource "helm_release" "wireguard_operator" {
  name       = "wireguard-operator"
  repository = "https://nccloud.github.io/charts"
  chart      = "wireguard-operator"
  version    = var.helm_version
  namespace  = var.namespace

  # Chart 0.3.0 ships the CRDs in crds/, so they exist by the time the
  # Wireguard/WireguardPeer manifests (server.tf/peers.tf) are applied.
  wait    = true
  timeout = 600
  values  = [yamlencode(local.helm_values)]

  depends_on = [kubernetes_namespace_v1.namespace]
}

