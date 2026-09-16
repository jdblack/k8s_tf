locals {
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
        # yamlencode renders null as "null" rather than omitting the key.
        var.load_balancer_ip != null ? { loadBalancerIP = var.load_balancer_ip } : {}
      )
    }
    nginxGateway = {
      gatewayClassName      = var.name
      gatewayControllerName = "gateway.nginx.org/${var.name}-controller"
      watchNamespaces       = var.watch_namespaces
    }
    # The chart's fixed defaults (server-tls / agent-tls) collide when two NGF
    # releases share a namespace, so derive names from the release.
    certGenerator = {
      serverTLSSecretName = "${var.release_name}-server-tls"
      agentTLSSecretName  = "${var.release_name}-agent-tls"
    }
  }

  # `nginx-gateway.fullname` from the chart's _helpers.tpl: the release name when it already
  # contains the chart name, otherwise `<release>-<chart>`. The cert-generator Job is
  # `<fullname>-cert-generator`, and its pod carries no chart labels -- only `job-name` -- so a
  # caller that closes a namespace needs this name to grant that pod API access.
  ngf_fullname = strcontains(var.release_name, "nginx-gateway-fabric") ? var.release_name : "${var.release_name}-nginx-gateway-fabric"
}
