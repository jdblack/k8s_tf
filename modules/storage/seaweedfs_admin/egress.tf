module "egress_outpost" {
  source    = "../../network/firewalls/policy"
  direction = "egress"

  namespace    = var.namespace
  name         = "authentik-outpost-egress"
  pod_selector = { "app.kubernetes.io/name" = "authentik-outpost" }

  peers = [{
    namespace    = var.auth_namespace
    pod_selector = { "app.kubernetes.io/name" = "authentik", "app.kubernetes.io/component" = "server" }
    ports        = [{ port = 9000 }]
  }]
}
