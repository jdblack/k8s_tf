module "ingress" {
  source    = "../../network/firewalls/policy"
  direction = "ingress"

  namespace = var.namespace
  name      = "seaweedfs-admin-ingress"

  pod_selector = {
    "app.kubernetes.io/name"     = "authentik-outpost"
    "app.kubernetes.io/instance" = var.outpost_name
  }

  peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = 9000 }]
  }]
}
