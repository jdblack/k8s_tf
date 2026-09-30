# Nothing outside the namespace calls the event sources; sensors reach the API instead.
module "ingress" {
  source    = "../../../network/firewalls/policy"
  direction = "ingress"

  namespace = var.namespace
  name      = "argo-events-ingress"
}
