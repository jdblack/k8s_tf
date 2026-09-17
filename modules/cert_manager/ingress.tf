# The guest list is the floor: the node addresses plus this namespace's pods, because the only inbound
# that matters is the apiserver calling the admission webhook -- and that arrives as the *sending* node's
# Calico IPIP tunnel address, never its InternalIP, which is why the floor reads both
# (`.clinedocs/calico-netpols.md`; this policy's first apply broke issuance cluster-wide until it did).
module "ingress" {
  source = "../network/firewalls/ingress"

  namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  name      = "cert-manager-ingress"
}
