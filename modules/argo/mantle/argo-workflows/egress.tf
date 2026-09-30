# Namespace-wide on purpose: workflows spawn arbitrary pods here that carry no
# fixed labels, so a pod_selector would leave those ungoverned.
module "egress" {
  source    = "../../../network/firewalls/policy"
  direction = "egress"

  namespace = var.namespace
  name      = "argo-workflows-egress"

  allow_k8s_api  = true
  allow_internet = true
}

module "egress_gateway" {
  source    = "../../../network/firewalls/policy"
  direction = "egress"

  namespace = var.namespace
  name      = "argo-workflows-gateway-egress"

  peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = 443 }]
  }]
}
