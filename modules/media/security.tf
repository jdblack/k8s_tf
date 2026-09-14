
# Namespace-wide egress: same-ns + DNS + internet, but NOT the k8s API. The
# only media workload that legitimately needs the API is the NGF control plane
# (+ its cert-generator job), which gets it from the pod-scoped allow_api below.
module "firewall" {
  source            = "../network/firewalls/basic_internet"
  namespace         = var.namespace
  allow_to_services = false
  allow_to_k8sapi   = false
}

# NetworkPolicies union, so NGF pods get the namespace-wide rules PLUS this.
# The arr apps and data-plane pods don't match the selector and stay API-denied.
module "allow_api" {
  source    = "../network/firewalls/allow_api"
  namespace = var.namespace
  pod_selector = {
    "app.kubernetes.io/name" = "nginx-gateway-fabric"
  }
}

# Ingress lockdown: only same-namespace, WireGuard clients (kube-network-vpn,
# who land on the wg-server pod) and non-pod external sources may connect.
# Everything else -- above all every other pod in the cluster, kube-network
# included -- is denied, so the arr ClusterIPs can't be reached around the
# authentik outpost. That is the point of the policy.
#
# The LoadBalancer apps are reached from OUTSIDE the cluster where the client is
# never a pod, so they need ipBlock peers: media's LBs are WAN-port-forwarded,
# hence 0.0.0.0/0 with the cluster CIDRs excluded (var.lan_cidrs listed too, for
# clarity).
#
# policy_name must differ from module.firewall above: basic_internet already
# owns "namespace-firewall" in this namespace.
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

# kube-network's only legitimate ingress is the shared public gateway proxying
# to plex (the sole media app on a shared gateway; every arr app is fronted by
# the media-private gateway in THIS namespace). Pod-scoped so an
# internet-facing gateway data plane there cannot reach the authentik-protected
# arr ClusterIPs. The namespace-wide policy above still covers plex's LAN/LB
# paths; this just adds the kube-network peer for plex.
module "firewall_ingress_plex" {
  source       = "../network/firewalls/limited_ingress"
  namespace    = var.namespace
  policy_name  = "namespace-ingress-plex"
  pod_selector = { "app.kubernetes.io/name" = "plex-media-server" }

  allowed_ingress_namespaces = ["kube-network"]
}


