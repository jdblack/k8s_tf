module "egress" {
  source = "../../network/firewalls/egress"

  namespace    = var.namespace
  name         = "harbor-egress"
  pod_selector = { "app.kubernetes.io/name" = "harbor" }
}

module "egress_trivy" {
  source = "../../network/firewalls/egress"

  namespace      = var.namespace
  name           = "harbor-trivy-egress"
  pod_selector   = { "app.kubernetes.io/component" = "trivy" }
  allow_internet = true
}

module "egress_core" {
  source = "../../network/firewalls/egress"

  namespace    = var.namespace
  name         = "harbor-core-gateway-egress"
  pod_selector = { "app.kubernetes.io/component" = "core" }

  to_peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = 443 }]
  }]
}
