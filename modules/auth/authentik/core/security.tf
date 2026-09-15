
# Egress: same-ns postgres/redis + DNS + internet. Ingress stays open on purpose:
# browsers reach authentik through the private gateway.
module "firewall" {
  source    = "../../../network/firewalls/basic_internet"
  namespace = var.namespace

  depends_on = [helm_release.helm]
}

# Pod-scoped API egress for the WORKER only. outpost_service_connection_monitor
# health-checks the media-proxy outpost's service connection (/version/), which
# post-DNAT is the control-plane :6443 inside blocked_egress_cidrs, so the outpost
# would show unhealthy forever. Policies union, so this wins over the `except`.
module "allow_api" {
  source    = "../../../network/firewalls/allow_api"
  namespace = var.namespace

  pod_selector = {
    "app.kubernetes.io/name"      = "authentik"
    "app.kubernetes.io/component" = "worker"
  }

  # This module is called under a module-level `depends_on` (stacks/core/auth.tf),
  # which defers the firewall's own endpoints read -- see allow_api/variables.tf.
  api_peer_ips = var.api_peer_ips

  depends_on = [helm_release.helm]
}
