locals {
  helm_values = {
    crds = {
      enabled = true
      keep    = true
    }

    config = {
      enableGatewayAPI            = true
      enableGatewayAPIListenerSet = true
      gatewayAPI = {
        enabled           = true
        enableListenerSet = true
      }
    }

    featureGates = "ListenerSets=true"

    extraArgs = [
      "--dns01-recursive-nameservers=8.8.8.8:53,1.1.1.1:53",
      "--dns01-recursive-nameservers-only",
    ]
  }
}
