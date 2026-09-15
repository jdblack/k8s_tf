
# Namespace-wide egress: same-ns + DNS + internet, but NOT the k8s API.
module "firewall" {
  source            = "../network/firewalls/basic_internet"
  namespace         = var.namespace
  allow_to_services = false
  allow_to_k8sapi   = false
}

# NetworkPolicies union, so NGF (which needs the API for cert generation) gets the
# namespace-wide rules PLUS this; the arr and data-plane pods stay API-denied.
module "allow_api" {
  source    = "../network/firewalls/allow_api"
  namespace = var.namespace
  pod_selector = {
    "app.kubernetes.io/name" = "nginx-gateway-fabric"
  }
}

# Ingress lockdown: only same-namespace, WireGuard clients (kube-network-vpn, who
# land on the wg-server pod) and non-pod external sources may connect. Every other
# pod, kube-network included, is denied -- so the arr ClusterIPs can't be reached
# around the authentik outpost.
#
# The LoadBalancer apps are reached from outside the cluster, where the client is
# never a pod, so they need ipBlock peers: media's LBs are WAN-port-forwarded, hence
# 0.0.0.0/0 with the cluster CIDRs excluded.
#
# policy_name must differ from module.firewall above: basic_internet already owns
# "namespace-firewall" here.
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

# kube-network's only legitimate ingress is the public gateway proxying to plex
# (the sole media app on a shared gateway). Pod-scoped so that internet-facing
# gateway data plane cannot reach the authentik-protected arr ClusterIPs; the
# namespace-wide policy above still covers plex's LAN/LB paths.
module "firewall_ingress_plex" {
  source       = "../network/firewalls/limited_ingress"
  namespace    = var.namespace
  policy_name  = "namespace-ingress-plex"
  pod_selector = { "app.kubernetes.io/name" = "plex-media-server" }

  allowed_ingress_namespaces = ["kube-network"]
}


