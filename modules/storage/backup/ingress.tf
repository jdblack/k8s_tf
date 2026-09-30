# velero serves /metrics on its API port, so prometheus needs a rule too.
module "ingress" {
  source    = "../../network/firewalls/policy"
  direction = "ingress"

  namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  name      = "velero-ingress"

  peers = [{
    namespace    = var.monitoring_namespace
    pod_selector = { "app.kubernetes.io/name" = "prometheus" }
    ports        = [{ port = 8085 }]
  }]
}
