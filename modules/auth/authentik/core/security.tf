
# Egress: same-ns postgres/redis + DNS + internet. Ingress is left open on
# purpose: browsers reach authentik through the private gateway, and a guest
# list buys little before the cluster's inbound paths are audited.
#
# The WORKER still needs the k8s API: outpost_service_connection_monitor
# health-checks the media-proxy outpost's service connection (/version/), which
# post-DNAT is the control-plane endpoint 192.168.0.74:6443 -- inside
# blocked_egress_cidrs -- so without the allow_api below the outpost shows
# unhealthy forever (seen in Whisker as kube-auth -> tcp:6443 Deny).
# Pod-scoped, not allow_to_k8sapi, so server/postgres stay API-denied.
module "firewall" {
  source    = "../../../network/firewalls/basic_internet"
  namespace = var.namespace

  depends_on = [helm_release.helm]
}

# Pod-scoped API egress for the worker ONLY -- allow_to_k8sapi above would hand
# the API to authentik-server and postgresql too. NetworkPolicies union, so this
# wins over the namespace-wide RFC1918 `except` for the selected pods.
module "allow_api" {
  source    = "../../../network/firewalls/allow_api"
  namespace = var.namespace

  pod_selector = {
    "app.kubernetes.io/name"      = "authentik"
    "app.kubernetes.io/component" = "worker"
  }

  depends_on = [helm_release.helm]
}
