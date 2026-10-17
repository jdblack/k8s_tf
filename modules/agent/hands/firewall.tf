# ★ THE GATEWAY MUST BE ADMITTED EXPLICITLY. The room's baseline ingress admits same-namespace
# callers and the node floor, NOT another namespace — so without this the doorbell is fully wired and
# completely unreachable: cert issued, ListenerSet Programmed, HTTPRoute created, and every request
# from the gateway dropped by the fence. Measured 2026-10-17 on the first greenfield apply.
# One pod, one port: the door.
module "ingress_gateway" {
  source = "../../network/firewalls/policy"
  count  = var.expose ? 1 : 0

  direction    = "ingress"
  namespace    = var.namespace
  name         = "${var.name}-door-ingress"
  pod_selector = local.labels

  peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = var.port }]
  }]
}

# ★ THE REPO IS IN ANOTHER ROOM, SO IT NEEDS ITS OWN DOOR. `allow_internet` is 0.0.0.0/0 MINUS the
# LAN, and Forgejo is an in-cluster ClusterIP — so a hand with "internet" still cannot reach the place
# its own code lives. Measured 2026-10-17 from `stet-hand`: DNS resolved `forgejo-http` to
# 10.98.179.155 and the TCP connect hung, which is the failure that looks like a slow git.
#
# ONE destination, ONE port, HTTP only: this buys `git clone/push`, not a general path to the estate.
# Off unless the caller names a namespace, because a room with no forgejo should not have the rule.
# ★ THE REPO IS SOUGHT THROUGH THE GATEWAY, NOT AT ITS POD. First attempt (withdrawn on review) put a
# direct egress peer on the Forgejo namespace, and then asked the Forgejo module to learn my name —
# a shared service taught about its tenants. The house already has the right shape: `immich` reaches
# the AUTH GATEWAY as a peer, and the Forgejo runner "polls the instance over its public name,
# through the same gateway as everyone else".
#
# So: one peer, port 443, the private gateway's data plane. Forgejo needs NO change — its own ingress
# already admits the gateway pod on 3000. The hostname still has to mean something inside the pod
# (the public name resolves to the LAN VIP, which no pod can route), hence the hostAlias in main.tf.
module "egress_repo" {
  source = "../../network/firewalls/policy"
  count  = var.repo_host == "" ? 0 : 1

  direction    = "egress"
  namespace    = var.namespace
  name         = "${var.name}-repo-egress"
  pod_selector = local.labels

  peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = 443 }]
  }]
}

# The model API is the only thing a hand needs OUTSIDE its own room besides the repo: the brain is a
# same-namespace ClusterIP, so the baseline egress already covers it. `allow_internet` is 0.0.0.0/0
# minus the LAN, so the pod still cannot reach internal services or the cluster API's VIPs.
module "egress_internet" {
  source = "../../network/firewalls/policy"

  direction      = "egress"
  namespace      = var.namespace
  name           = "${var.name}-internet-egress"
  pod_selector   = local.labels
  allow_internet = true
}
