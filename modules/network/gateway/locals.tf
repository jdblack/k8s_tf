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
    # Derive from the release: the chart's fixed server-tls / agent-tls names collide when two NGF
    # releases share a namespace.
    certGenerator = {
      serverTLSSecretName = "${var.release_name}-server-tls"
      agentTLSSecretName  = "${var.release_name}-agent-tls"
    }
  }

  # `nginx-gateway.fullname` from the chart's _helpers.tpl (the release name when it already contains
  # the chart name), so a caller closing a namespace can name the cert-generator Job: its pod carries
  # only `job-name`, no chart labels.
  ngf_fullname = strcontains(var.release_name, "nginx-gateway-fabric") ? var.release_name : "${var.release_name}-nginx-gateway-fabric"
}
