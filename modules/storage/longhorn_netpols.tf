module "ingress_longhorn_system" {
  source    = "../network/firewalls/policy"
  direction = "ingress"

  namespace = var.longhorn_namespace
  name      = "longhorn-system-ingress"
}
