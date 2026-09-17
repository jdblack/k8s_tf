# The namespace's only door is the gateway: Grafana on the pod's own :3000 (the Service says :80 --
# post-DNAT again), and every other flow into here is Prometheus scraping something in here.
# `pod_selector` omitted, so the whole namespace is covered. The six node-exporter pods that sit in this
# namespace with *node* addresses are not covered and cannot be: host-network pods are outside pod
# policy entirely (`.clinedocs/calico-netpols.md`), which is also why no guest list can ever name them.
module "ingress" {
  source = "../../network/firewalls/ingress"

  namespace = var.namespace
  name      = "monitoring-ingress"

  from_peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = 3000 }]
  }]
}
