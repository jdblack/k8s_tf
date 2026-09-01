locals {
  # ListenerSets (declared by each app module in the app namespace) may attach
  # their HTTPS listeners to this Gateway. routes_namespace restricts attachment
  # to that namespace; when unset (null) any namespace may attach.
  allowed_listeners = {
    namespaces = merge(
      { from = var.routes_namespace != null ? "Selector" : "All" },
      var.routes_namespace != null ? {
        selector = {
          matchLabels = {
            "kubernetes.io/metadata.name" = var.routes_namespace
          }
        }
      } : {}
    )
  }

  helm_values = {
    nginx = {
      service = merge(
        { type = "LoadBalancer" },
        # yamlencode renders null as "null" (not omits it), so only set the
        # key when the caller pinned an IP.
        var.load_balancer_ip != null ? { loadBalancerIP = var.load_balancer_ip } : {}
      )
    }
    nginxGateway = {
      gatewayClassName      = var.name
      gatewayControllerName = "gateway.nginx.org/${var.name}-controller"
      watchNamespaces       = var.watch_namespaces
    }
    # The chart defaults both TLS secret names to a fixed value (server-tls /
    # agent-tls), which collides when multiple NGF releases share a namespace
    # (public + private in kube-network). Derive unique names from the release.
    certGenerator = {
      serverTLSSecretName = "${var.release_name}-server-tls"
      agentTLSSecretName  = "${var.release_name}-agent-tls"
    }
  }
}
