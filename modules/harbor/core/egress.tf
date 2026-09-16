# Egress for the Harbor release. Three policies rather than one, because the seven pods the
# chart ships fall into three profiles -- and Calico *unions* the rules of every policy that
# selects a pod, so the two narrow ones compose with the base instead of restating it:
#
#   harbor-egress               app.kubernetes.io/name=harbor       all seven   DNS + own namespace
#   harbor-trivy-egress         app.kubernetes.io/component=trivy   trivy       + the internet
#   harbor-core-gateway-egress  app.kubernetes.io/component=core    core        + the private gateway, TCP/443
#
# Labels are the chart's own, checked live: all seven pods carry app.kubernetes.io/name=harbor
# and app.kubernetes.io/component= core|database|jobservice|portal|redis|registry|trivy.
#
# What the base deliberately omits, read off a 30-day Whisker window for this namespace (six
# flow shapes in total, all UDP/53 to coredns and intra-namespace): no allow_k8s_api, no LAN, no
# kube-storage peer. The last is the same finding as media's -- these PVCs are seaweedfs-csi
# bind mounts, so the client owning that traffic is the CSI DaemonSet in kube-storage, not any
# pod's netns here.
module "egress" {
  source = "../../network/firewalls/egress"

  namespace    = var.namespace
  name         = "harbor-egress"
  pod_selector = { "app.kubernetes.io/name" = "harbor" }
}

# trivy is the only pod here with an off-cluster dependency: it fetches its own databases
# (SCANNER_TRIVY_DB_REPOSITORY=mirror.gcr.io/aquasec/trivy-db,ghcr.io/aquasecurity/trivy-db and
# the java one beside it, with SKIP_UPDATE=false and SKIP_JAVA_DB_UPDATE=false). This is
# "absence of flow is not absence of traffic" in its purest form -- the pulls are bursty (a DB
# rotation, a first scan of a new image) and the window contains none of them, so a DNS+self
# policy here would look correct against the log and break the first scan after the next
# rotation. Public registries over 443, so allow_internet is the entire grant: it excludes
# RFC1918 and nothing in this pod talks to the LAN. GITHUB_TOKEN is empty, so no API peer.
module "egress_trivy" {
  source = "../../network/firewalls/egress"

  namespace      = var.namespace
  name           = "harbor-trivy-egress"
  pod_selector   = { "app.kubernetes.io/component" = "trivy" }
  allow_internet = true
}

# harbor-core re-enters the cluster through the private gateway to speak OIDC. harbor/mantle sets
# oauth2_server = auth.<domain> (it lands in Harbor's own database as `oidc_endpoint`, with
# `oidc_verify_cert = true`), so the server-side half of OIDC -- the discovery document, then the
# JWKS -- dials that *public* URL, which split-horizon DNS points at the private gateway's VIP.
# Measured from this pod before any policy existed: 200, remote_ip=192.168.0.100.
#
# The peer is the gateway's data plane, NOT the VIP, and that is measured rather than reasoned: a
# `to_cidrs = ["192.168.0.100/32"]` rule on this very pod permitted nothing. The dial stayed dead
# (curl exit 28, 25 s timeout) while DNS and the self rule kept working, because egress is
# evaluated POST-DNAT (`.clinedocs/calico-netpols.md`). The Whisker deny record names the flow the
# policy actually sees:
#   harbor-core-*  ->  private-private-6f99f96d5f-* :443/tcp   (kube-network, a data plane pod)
# So the peer is namespace + pod selector + port, which is why this call is `egress_peer` and not
# the base builder: `to_namespaces` would take all of kube-network on every port, and a CIDR is
# inert in principle, not just here. 443 is the gateway's HTTPS port and the only one in play --
# both shared gateways drop plain HTTP.
#
# Same trap as trivy's, one level up: Harbor caches the OIDC provider, so a policy missing this
# peer looks fine until the cache expires or the pod restarts, and then only login breaks -- the
# UI itself still loads, and the flow window shows none of the traffic.
module "egress_core" {
  source = "../../network/firewalls/egress_peer"

  namespace    = var.namespace
  name         = "harbor-core-gateway-egress"
  pod_selector = { "app.kubernetes.io/component" = "core" }

  # The label NGF stamps on the data plane, the same one media's own data-plane policy selects:
  # it tracks var.gateway_name, so this follows a renamed gateway.
  to_peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = 443 }]
  }]
}
