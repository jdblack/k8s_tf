
# Egress: same-ns postgres/redis + DNS + internet. Ingress stays open on purpose:
# browsers reach authentik through the private gateway, and a guest list buys little
# before the cluster's inbound paths are audited.
module "firewall" {
  source    = "../../../network/firewalls/basic_internet"
  namespace = var.namespace

  depends_on = [helm_release.helm]
}

# Pod-scoped API egress for the WORKER only -- allow_to_k8sapi above would hand the
# API to authentik-server and postgresql too. Needed because
# outpost_service_connection_monitor health-checks the media-proxy outpost's service
# connection (/version/), which post-DNAT is the control-plane endpoint :6443 --
# inside the RFC1918 blocked_egress_cidrs -- so the outpost would show unhealthy
# forever. NetworkPolicies union, so this wins over the namespace-wide `except`.
module "allow_api" {
  source    = "../../../network/firewalls/allow_api"
  namespace = var.namespace

  pod_selector = {
    "app.kubernetes.io/name"      = "authentik"
    "app.kubernetes.io/component" = "worker"
  }

  # Required whenever this module is called under a module-level `depends_on` -- which
  # it is (stacks/core/auth.tf): `depends_on` defers data sources inside the module
  # to apply time, the API netpol then plans a guessed peer count and the apply dies
  # with "inconsistent final plan". See ../../network/firewalls/allow_api/variables.tf.
  api_peer_ips = var.api_peer_ips

  depends_on = [helm_release.helm]
}
