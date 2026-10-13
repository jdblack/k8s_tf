# The guardrail that IS the "don't get arrested" clause: a runaway experiment here cannot eat the
# node. Raise these deliberately, never blindly.
resource "kubernetes_resource_quota_v1" "quota" {
  metadata {
    name      = "cline-home-quota"
    namespace = kubernetes_namespace_v1.home.metadata[0].name
    labels    = local.labels
  }

  spec {
    hard = {
      "pods"                   = "20"
      "requests.cpu"           = "2"
      "requests.memory"        = "4Gi"
      "limits.cpu"             = "4"
      "limits.memory"          = "8Gi"
      "persistentvolumeclaims" = "5"
      "requests.storage"       = "20Gi"
      "services"               = "10"
      "configmaps"             = "50"
      "secrets"                = "50"
    }
  }
}

# A single monster pod is the other way to hurt the node, so cap per-container too.
resource "kubernetes_limit_range_v1" "defaults" {
  metadata {
    name      = "cline-home-defaults"
    namespace = kubernetes_namespace_v1.home.metadata[0].name
    labels    = local.labels
  }

  spec {
    limit {
      type            = "Container"
      default         = { cpu = "250m", memory = "256Mi" }
      default_request = { cpu = "50m", memory = "128Mi" }
      max             = { cpu = "2", memory = "4Gi" }
    }
  }
}
