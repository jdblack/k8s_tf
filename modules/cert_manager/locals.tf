locals {
  helm_values = {
    crds = {
      # Replaces the deprecated `installCRDs` flag (removed from newer charts).
      # `installCRDs: true` was equivalent to `crds.enabled=true, crds.keep=true`
      # (keep adds helm.sh/resource-policy: keep so uninstall leaves CRDs behind).
      enabled = true
      keep    = true
    }

    # Enable cert-manager's gateway-shim so it auto-provisions per-listener
    # Certificates for annotated Gateways and ListenerSets.
    config = {
      enableGatewayAPI            = true
      enableGatewayAPIListenerSet = true
      gatewayAPI = {
        enabled           = true
        enableListenerSet = true
      }
    }

    # Enable cert-manager's `listenerset` controller (Alpha feature gate,
    # v1.21) so it auto-provisions per-listener Certificates for annotated
    # ListenerSets in ANY namespace -- including cross-namespace attachments
    # to the shared public/private gateways in kube-network.
    featureGates = "ListenerSets=true"

    # Split-horizon DNS. The cluster resolves through the LAN resolver, which is
    # authoritative for vn.linuxguru.net (bind9) and has never seen the
    # `_acme-challenge` TXT: that record lives in the Route53 linuxguru.net zone.
    # cert-manager reads the authoritative view from the pod's /etc/resolv.conf
    # for both zone discovery and the DNS-01 self-check, so point it at public
    # resolvers. For a .vn host the default answer is bind9 -- a zone that does
    # not exist in Route53, and a TXT that is not in this view.
    extraArgs = [
      "--dns01-recursive-nameservers=8.8.8.8:53,1.1.1.1:53",
      "--dns01-recursive-nameservers-only",
    ]
  }
}
