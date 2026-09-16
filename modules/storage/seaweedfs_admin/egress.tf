# Stated here rather than in the shared `proxy_outpost` module: the namespace profile already grants
# the in-namespace hop to the admin UI, and the identity peer is one pod on :9000 -- post-DNAT, so a
# rule naming the Service's :80 would permit nothing.
module "egress_outpost" {
  source = "../../network/firewalls/egress_peer"

  namespace    = var.namespace
  name         = "authentik-outpost-egress"
  pod_selector = { "app.kubernetes.io/name" = "authentik-outpost" }

  to_peers = [{
    namespace    = var.auth_namespace
    pod_selector = { "app.kubernetes.io/name" = "authentik", "app.kubernetes.io/component" = "server" }
    ports        = [{ port = 9000 }]
  }]
}
