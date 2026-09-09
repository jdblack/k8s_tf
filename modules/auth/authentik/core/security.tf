
# Egress firewall for the Authentik namespace.
#
# server/worker only talk to their bundled postgres + redis (same namespace),
# DNS, and public internet. No proxy providers / outposts are created here, so
# there is no cross-namespace egress to gateways or app backends and no k8s
# API access needed.
#
# Ingress is intentionally left open: browsers reach authentik through the
# shared private gateway, and an ingress restriction buys little until the
# cluster's inbound paths are audited (and would need a "allow kube-network"
# variant of the ingress policy that doesn't exist yet).
module "firewall" {
  source    = "../../../network/firewalls/basic_internet"
  namespace = var.namespace

  depends_on = [helm_release.helm]
}
