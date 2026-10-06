module "ingress_baseline" {
  source    = "../network/firewalls/policy"
  direction = "ingress"

  namespace = var.namespace
  name      = "kube-storage-baseline-ingress"

  peers = [
    {
      namespace    = var.gateway_namespace
      pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
      ports        = [{ port = 8333 }, { port = 9333 }, { port = 9101 }]
    },
    {
      namespace    = var.monitoring_namespace
      pod_selector = { "app.kubernetes.io/name" = "prometheus" }
      ports        = [{ port = 9327 }]
    },
  ]
}
