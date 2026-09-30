# No netpols by intent: clients must reach the LAN, which firewalls/policy can't express.
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
