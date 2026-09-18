module "ingress" {
  source = "../network/firewalls/ingress"

  namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  name      = "cert-manager-ingress"
}
