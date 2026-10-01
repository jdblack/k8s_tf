# Baseline admit for the namespace itself: the oCIS services talk to each other and the
# gateway listener, and the controller needs to reach every pod. Node IPs come with the
# module, so kubelet probes and CNI health checks survive the default-deny.
module "ingress_baseline" {
  source    = "../network/firewalls/policy"
  direction = "ingress"

  namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  name      = "documents-ingress"
}
