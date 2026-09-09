
# Egress firewall for the cert-manager namespace.
#
# Everything cert-manager runs (controller, cainjector, webhook, ACME pods)
# only needs: same-namespace traffic, DNS, the Kubernetes API server (it
# watches/patches Certificate resources; the webhook is called by the API
# server, which is inbound) and public internet (Let's Encrypt + Route53 for
# the external issuer).
#
# Deliberately NO ingress policy here: the kube-apiserver calls the
# cert-manager webhook from the nodes (host traffic, not from a pod
# namespace), so restricting ingress would break certificate issuance
# cluster-wide. Egress-only keeps the lateral-movement win without that risk.
module "firewall" {
  source          = "../network/firewalls/basic_internet"
  namespace       = var.namespace
  allow_to_k8sapi = true

  depends_on = [kubernetes_namespace_v1.namespace]
}
