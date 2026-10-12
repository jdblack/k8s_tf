# Auto host endpoints: kube-controllers stamps one wildcard HostEndpoint per node carrying the
# node's labels and its IPs -- the InternalIP *and* the Calico IPIP tunnel address -- so node
# traffic can be admitted by identity instead of per-node /32 ip_blocks. Allow-all profile:
# no host lockout.
resource "kubectl_manifest" "auto_host_endpoints" {
  apply_only = true

  yaml_body = yamlencode({
    apiVersion = "projectcalico.org/v3"
    kind       = "KubeControllersConfiguration"
    metadata   = { name = "default" }
    spec = {
      controllers = {
        node = {
          hostEndpoint = {
            autoCreate                = "Enabled"
            createDefaultHostEndpoint = "Enabled"
          }
        }
      }
    }
  })
}
