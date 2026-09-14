
# Egress: same-ns + DNS + the k8s API (cert-manager watches/patches
# Certificates) + internet (Let's Encrypt, Route53).
#
# Deliberately NO ingress policy: the kube-apiserver calls the webhook from the
# nodes (host traffic, not a pod namespace), so restricting ingress would break
# certificate issuance cluster-wide. Egress-only keeps the lateral-movement win
# without that risk.
module "firewall" {
  source          = "../network/firewalls/basic_internet"
  namespace       = var.namespace
  allow_to_k8sapi = true

  depends_on = [kubernetes_namespace_v1.namespace]
}
