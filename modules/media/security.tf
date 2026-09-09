
# Namespace-wide egress firewall. Radarr/sonarr/plex/qbittorrent/prowlarr (and
# the media-private data-plane pods) get same-namespace + DNS + internet --
# but NOT the Kubernetes API server. A compromised media app should not have a
# line to the API.
#
# The only media-namespace workload that legitimately needs the API is the NGF
# control plane (media-private gateway controller + its chart cert-generator
# job), which lives in this namespace (api_gateway.tf). It gets API egress via
# the pod-scoped allow_api module below instead of a namespace-wide carve-out
# (see modules/network/firewalls/allow_api/README.md -- this is the canonical
# example of when to prefer pod-scoped over basic_internet.allow_to_k8sapi).
module "firewall" {
  source            = "../network/firewalls/basic_internet"
  namespace         = var.namespace
  allow_to_services = false
  allow_to_k8sapi   = false
}

# Pod-scoped egress to the Kubernetes API for the media-private NGF control
# plane only. Kubernetes NetworkPolicies are additive (union), so the NGF
# controller pods get the namespace-wide rules from module.firewall PLUS this
# API rule; the arr apps and data-plane pods don't match the selector and stay
# API-denied.
module "allow_api" {
  source    = "../network/firewalls/allow_api"
  namespace = var.namespace
  pod_selector = {
    "app.kubernetes.io/name" = "nginx-gateway-fabric"
  }
}


