
# Egress: same-ns + DNS + the k8s API (cert-manager watches/patches Certificates) +
# internet (Let's Encrypt, Route53).
#
# Deliberately NO ingress policy: the kube-apiserver calls the webhook from the nodes
# (host traffic, not a pod namespace), so restricting ingress would break certificate
# issuance cluster-wide.
module "firewall" {
  source           = "../network/firewalls/basic_egress"
  namespace        = var.namespace
  allow_namespaces = [var.namespace]
  allow_internet   = true
  allow_k8s_api    = true

  api_peer_ips = var.api_peer_ips

  depends_on = [kubernetes_namespace_v1.namespace]
}
