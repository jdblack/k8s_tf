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
  }
}
