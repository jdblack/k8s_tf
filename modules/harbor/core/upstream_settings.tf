# Explicit least_conn load balancing for harbor's backend services.
#
# Unlike ClientSettingsPolicy, UpstreamSettingsPolicy can only target Services
# in the policy's own namespace (not a Gateway), so this must live in the app
# module rather than the gateway module. Note: NGF's built-in default is
# already "random two least_conn" (a least-connections algorithm), so this is
# making the operator's preferred variant explicit.
resource "kubernetes_manifest" "upstream_settings" {
  manifest = {
    apiVersion = "gateway.nginx.org/v1alpha1"
    kind       = "UpstreamSettingsPolicy"
    metadata = {
      name      = "harbor-upstream-settings"
      namespace = var.namespace
    }
    spec = {
      targetRefs = [
        {
          group = ""
          kind  = "Service"
          name  = "harbor-core"
        },
        {
          group = ""
          kind  = "Service"
          name  = "harbor-portal"
        },
      ]
      loadBalancingMethod = "least_conn"
    }
  }

  depends_on = [helm_release.harbor]
}
