locals {
  # Routes (HTTPRoutes in the app namespace) may attach to the :80 listener.
  allowed_routes = {
    namespaces = {
      from = "Selector"
      selector = {
        matchLabels = {
          "kubernetes.io/metadata.name" = var.routes_namespace
        }
      }
    }
  }

  # ListenerSets (declared by each app module in the app namespace) may attach
  # their HTTPS listeners to this Gateway.
  allowed_listeners = {
    namespaces = {
      from = "Selector"
      selector = {
        matchLabels = {
          "kubernetes.io/metadata.name" = var.routes_namespace
        }
      }
    }
  }
}
