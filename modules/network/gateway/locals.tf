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
}
