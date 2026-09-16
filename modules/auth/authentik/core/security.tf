
# Egress: same-ns postgres/redis + DNS + internet. Ingress stays open on purpose:
# browsers reach authentik through the private gateway.
module "firewall" {
  source    = "../../../network/firewalls/basic_internet"
  namespace = var.namespace

  depends_on = [helm_release.helm]
}

# Pod-scoped API egress for the WORKER only. authentik's own
# outpost_connection_discovery re-creates a local KubernetesServiceConnection
# ("Local Kubernetes Cluster") whenever none exists, and outposts.models gives EVERY such
# connection a periodic outpost_service_connection_monitor task (crontab 3-59/15 * * * *),
# which calls KubernetesClient.fetch_state() -> control-plane :6443. That is inside
# blocked_egress_cidrs, so without this the connection reports unhealthy forever and the
# worker logs the failure every 15 minutes. Deleting the connection object in Terraform
# would achieve nothing: discovery puts it back within 8 hours. Policies union, so this
# wins over the `except`.
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
