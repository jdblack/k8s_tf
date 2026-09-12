
# Egress firewall for the Authentik namespace.
#
# server/worker only talk to their bundled postgres + redis (same namespace),
# DNS, and public internet. No proxy providers / outposts are *deployed* here
# (the outpost pods live in `media`), so there is no cross-namespace egress to
# gateways or app backends from this namespace.
#
# The k8s API is still needed by the WORKER, though: it runs
# `authentik.outposts.tasks.outpost_service_connection_monitor`, which
# health-checks the media-proxy outpost's Kubernetes service connection by
# calling the API (`/version/`). That is 10.96.0.1:443, post-DNAT the
# control-plane endpoint (192.168.0.74:6443) -- both inside
# `blocked_egress_cidrs` -- so without the `allow_api` module below the monitor
# times out forever and the outpost shows as unhealthy in the UI. Verified in
# Whisker: kube-auth -> PRIVATE NETWORK tcp:6443 Deny, trigger
# "namespace-firewall". The chart's `authentik` ServiceAccount +
# `authentik-kube-auth` ClusterRoleBinding (list customresourcedefinitions exist
# for this) is the intended path.
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

# Pod-scoped API egress for the worker ONLY. Deliberately not
# `allow_to_k8sapi = true` above: that would hand the API to
# authentik-server and authentik-postgresql as well (see the basic_internet
# README). NetworkPolicies union, so this allow wins over the namespace-wide
# policy's RFC1918 `except` for the pods matching the selector -- same
# mechanism `media` uses for its NGF control plane.
module "allow_api" {
  source    = "../../../network/firewalls/allow_api"
  namespace = var.namespace

  pod_selector = {
    "app.kubernetes.io/name"      = "authentik"
    "app.kubernetes.io/component" = "worker"
  }

  depends_on = [helm_release.helm]
}
