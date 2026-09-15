locals {
  helm_values = {
    crds = {
      # Replaces the deprecated `installCRDs` flag; `keep` adds
      # helm.sh/resource-policy: keep so uninstall leaves CRDs behind.
      enabled = true
      keep    = true
    }

    # gateway-shim: auto-provisions per-listener Certificates for annotated Gateways
    # and ListenerSets.
    config = {
      enableGatewayAPI            = true
      enableGatewayAPIListenerSet = true
      gatewayAPI = {
        enabled           = true
        enableListenerSet = true
      }
    }

    # The `listenerset` controller (Alpha feature gate) is required for
    # cross-namespace attachments to the shared gateways in kube-network.
    featureGates = "ListenerSets=true"

    # Split-horizon DNS. The pod resolves through the LAN resolver, which is
    # authoritative for vn.linuxguru.net (bind9) and has never seen the
    # `_acme-challenge` TXT (that record lives in the Route53 linuxguru.net zone).
    # cert-manager uses that view for zone discovery AND the DNS-01 self-check, so
    # point it at public resolvers.
    extraArgs = [
      "--dns01-recursive-nameservers=8.8.8.8:53,1.1.1.1:53",
      "--dns01-recursive-nameservers-only",
    ]
  }
}
