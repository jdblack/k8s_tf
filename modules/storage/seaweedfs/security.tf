# SeaweedFS is exposed to a deliberately small peer set: its own namespace, the
# shared gateways in kube-network (there is NO LoadBalancer on seaweed itself) and
# monitoring (ServiceMonitor scrapes). Everything else reaches storage through the
# CSI driver, which runs inside this namespace.
module "firewall" {
  source = "../../network/firewalls/limited_ingress"

  namespace = var.namespace

  allowed_ingress_namespaces = [
    var.namespace,
    "kube-network",
    "monitoring",
  ]
}

