# Baseline: DNS and this namespace only. Plus the API server: the chart's config-generate hook
# runs kubectl (to persist `.runner` into a Secret), and without this the hook hangs forever.
module "egress_baseline" {
  source    = "../network/firewalls/policy"
  direction = "egress"

  namespace     = kubernetes_namespace_v1.namespace.metadata[0].name
  name          = "${var.name}-baseline-egress"
  allow_k8s_api = true
}

# The Forgejo instance, its git repos, and the upload of job logs/artifacts all ride the private
# gateway, so a single peer to the gateway pod covers them.
module "egress_gateway" {
  source    = "../network/firewalls/policy"
  direction = "egress"

  namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  name      = "${var.name}-gateway-egress"

  peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = 443 }]
  }]
}

# Actions and their base images are pulled from the public internet (data.forgejo.org, Docker Hub,
# ...), which the namespace baseline (DNS and self) does not admit.
module "egress_internet" {
  source    = "../network/firewalls/policy"
  direction = "egress"

  namespace      = kubernetes_namespace_v1.namespace.metadata[0].name
  name           = "${var.name}-internet-egress"
  allow_internet = true
}
