# SeaweedFS is intentionally exposed only to a small set of peers:
#   - its own namespace (master/filer/volume/s3/csi talk to each other),
#   - kube-network, the shared gateways that front the S3/admin/master
#     HTTPRoutes for LAN clients (there is NO LoadBalancer on seaweed itself),
#   - monitoring, so Prometheus can keep scraping the seaweed ServiceMonitors.
# Every other namespace (media, argo, harbor, longhorn, ...) is denied direct
# access to seaweed services; workloads that need seaweed storage reach it via
# the CSI driver, which runs inside this namespace.
module "firewall" {
  source = "../../network/firewalls/limited_ingress"

  namespace = var.namespace

  allowed_ingress_namespaces = [
    var.namespace,
    "kube-network",
    "monitoring",
  ]
}

