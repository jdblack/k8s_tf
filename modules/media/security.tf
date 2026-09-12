
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

# Ingress lockdown for the whole namespace. Only three classes of source may
# connect; everything else -- above all, every OTHER pod in the cluster -- is
# denied, so the arr ClusterIPs can no longer be reached directly (bypassing the
# authentik outpost). That is the whole point of this policy.
#
#   - same-namespace    : gateway <-> outpost <-> apps, NGF control/data plane
#   - kube-network-vpn  : WireGuard clients reaching the internal hostnames
#                         land via the wg-server pod (this namespace)
#   - kube-network      : deliberately NOT listed here -- only plex needs it,
#                         and it is scoped to the plex pods by the pod-scoped
#                         supplement below (see module.firewall_ingress_plex)
#   - non-pod sources   : the LoadBalancers are reached from OUTSIDE the
#                         cluster, where the client is never a pod, so only
#                         ipBlocks can match. Media's LBs are WAN-port-forwarded
#                         (router preserves the source IP) so clients/peers are
#                         public addresses -- hence 0.0.0.0/0 with the cluster's
#                         own pod/service CIDRs excluded. var.lan_cidrs is
#                         listed explicitly too, for clarity.
#
# policy_name must differ from module.firewall above: basic_internet already
# owns the "namespace-firewall" name in this namespace.
module "firewall_ingress" {
  source      = "../network/firewalls/limited_ingress"
  namespace   = var.namespace
  policy_name = "namespace-ingress"

  allowed_ingress_namespaces = [
    var.namespace,
    "kube-network-vpn",
  ]

  allowed_ingress_cidrs = concat(
    [for c in var.lan_cidrs : { cidr = c }],
    [{ cidr = "0.0.0.0/0", except = var.cluster_cidrs }],
  )
}

# kube-network's ONLY legitimate ingress into media is the shared public gateway
# proxying to plex (the sole media app fronted by a kube-network gateway -- see
# the plex-* ReferenceGrants; every arr app is fronted by the media-private
# gateway, which lives in THIS namespace). Scope it to the plex pods so a pod in
# kube-network -- notably an internet-facing gateway data plane -- cannot reach
# the authentik-protected arr ClusterIPs directly. Same guarantee the
# namespace-wide policy above gives against every other namespace.
#
# Pod-scoped supplement: the namespace-wide policy above still covers plex for
# the LAN/internet/LB paths (its ipBlock + same-namespace peers); this adds the
# kube-network peer to plex only.
module "firewall_ingress_plex" {
  source       = "../network/firewalls/limited_ingress"
  namespace    = var.namespace
  policy_name  = "namespace-ingress-plex"
  pod_selector = { "app.kubernetes.io/name" = "plex-media-server" }

  allowed_ingress_namespaces = ["kube-network"]
}


