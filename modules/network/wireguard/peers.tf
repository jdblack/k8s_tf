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
