module "egress" {
  source    = "../network/firewalls/policy"
  direction = "egress"

  namespace     = kubernetes_namespace_v1.namespace.metadata[0].name
  name          = "cert-manager-egress"
  allow_k8s_api = true
}

module "egress_controller" {
  source    = "../network/firewalls/policy"
  direction = "egress"

  namespace    = kubernetes_namespace_v1.namespace.metadata[0].name
  name         = "cert-manager-controller-egress"
  pod_selector = { "app.kubernetes.io/name" = "cert-manager", "app.kubernetes.io/component" = "controller" }

  allow_internet = true
}
