module "ingress_baseline" {
  source = "../network/firewalls/ingress"

  namespace = var.namespace
  name      = "kube-storage-baseline-ingress"

  from_peers = [
    {
      namespace    = var.gateway_namespace
      pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
      ports        = [{ port = 8333 }, { port = 9333 }, { port = 9000 }]
    },
    {
      namespace    = var.monitoring_namespace
      pod_selector = { "app.kubernetes.io/name" = "prometheus" }
      ports        = [{ port = 9327 }]
    },
    {
      # The backup namespace: velero and its node-agent both upload to S3.
      namespace = var.backup_namespace
      ports     = [{ port = 8333 }]
    },
  ]
}
