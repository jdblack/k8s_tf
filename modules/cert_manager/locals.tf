locals {
  helm_values = {
    crds = {
      # Replaces the deprecated `installCRDs`; `keep` adds helm.sh/resource-policy: keep, so uninstall
      # leaves the CRDs behind.
      enabled = true
      keep    = true
    }

    # gateway-shim: auto-provisions per-listener Certificates for annotated Gateways/ListenerSets.
    config = {
      enableGatewayAPI            = true
      enableGatewayAPIListenerSet = true
      gatewayAPI = {
        enabled           = true
        enableListenerSet = true
      }
    }

    # Alpha feature gate, required for cross-namespace attachments to the gateways in kube-network.
    featureGates = "ListenerSets=true"

    # Split-horizon DNS: the pod's resolver is the LAN bind9, authoritative for vn.linuxguru.net and
    # never holding the `_acme-challenge` TXT (that lives in the Route53 linuxguru.net zone), and
    # cert-manager uses that view for zone discovery AND the DNS-01 self-check -- so point it at public
    # resolvers.
    extraArgs = [
      "--dns01-recursive-nameservers=8.8.8.8:53,1.1.1.1:53",
      "--dns01-recursive-nameservers-only",
    ]
  }
}
