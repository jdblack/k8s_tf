resource "helm_release" "wireguard_operator" {
  name       = "wireguard-operator"
  repository = "https://nccloud.github.io/charts"
  chart      = "wireguard-operator"
  version    = var.chart_version
  namespace  = var.namespace

  # Pinned chart + image (NOT "latest"): see the Conventions section of
  # README.md (the systemic unpinned-helm note). Chart 0.3.0 ships the CRDs in
  # crds/, so they exist before the Wireguard/WireguardPeer manifests
  # (server.tf/peers.tf) are applied.
  values = [yamlencode(local.helm_values)]

  depends_on = [kubernetes_namespace_v1.namespace]
}

