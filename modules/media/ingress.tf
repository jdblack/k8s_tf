locals {
  # NGF names each Gateway's data-plane Deployment `<gateway>-<gatewayclass>`, and this repo's gateway
  # module sets the class to the gateway's own name -- live: `media-private-media-private` here,
  # `private-private` / `public-public` in `kube-network`. That Deployment's name is also the pods'
  # `app.kubernetes.io/name`. The pods' `gateway.networking.k8s.io/gateway-name` label says the same
  # thing more semantically, but it is a different key and a second `NotIn` would AND with the first,
  # deciding which pods the curtain covers at all.
  data_plane_name = "${var.gateway_name}-${var.gateway_name}"
}

# The ingress half of the profile in `egress.tf`, and the one place the two directions differ: on egress a
# pod's own profile is a *move* between call sites, here it is an **exclusion** from the curtain's own
# selector. Three pods are named out of the namespace-wide curtain, each because its door is not a pod:
#   * `plex` -- :32400 through its own LoadBalancer, measured `PUBLIC NETWORK -> plex-…:32400` (one of only
#     two cross-namespace inbound peers this namespace has), and the `public` gateway in `kube-network`
#     for the web UI;
#   * `qbittorrent` -- :21010 from torrent peers, same shape (`PUBLIC NETWORK -> qbittorrent-…:21010`);
#   * the `media-private` data plane -- the LAN front door for every arr UI here. All three
#     LoadBalancers are `externalTrafficPolicy: Local`, so a client's source address survives to the pod
#     and no peer list can state its guests. The other gateway data planes in the cluster are left
#     exactly like this (`network/netpols.tf` curates neither `private-private` nor `public-public`).
# Excluded means *unrestricted*, not "restricted differently": netpols union, so a carve here can only
# leave those pods as open as they already are. Accepted -- all three are WAN-facing by design.
#
# The guest list is the floor -- own namespace plus the node addresses -- and nothing else. The data plane
# is in this namespace, so the self rule admits it on every port, and the arr chatter rides the same rule
# (bazarr -> sonarr :8989, sonarr/radarr -> qbittorrent :8080, outpost -> the apps, data plane -> control
# plane :8443, the last of those the one Whisker does show). Data-plane -> app flows never appear at all:
# nginx holds its upstreams open, and a connection that never ends is never emitted
# (`.clinedocs/flow-logs.md`), so this call is argued from the topology and not from a flow list.
module "ingress_baseline" {
  source = "../network/firewalls/ingress"

  namespace = var.namespace
  name      = "media-ingress"

  # Not an allow-list of the pods to cover -- the inverse. `NotIn` matches a pod that lacks the key too
  # (measured, `notin` semantics in `.clinedocs/calico-netpols.md`), so the hand-made `utility` pod and
  # anything created here later land *inside* the curtain without being written down, and only a pod
  # carrying one of these three values is carved out. One expression, one key: two expressions AND, so a
  # `NotIn` on a second key would decide which pods the curtain covers at all.
  pod_selector_expressions = [{
    key      = "app.kubernetes.io/name"
    operator = "NotIn"
    values   = ["plex-media-server", "qbittorrent", local.data_plane_name]
  }]
}
