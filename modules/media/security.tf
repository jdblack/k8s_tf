
# Namespace-wide egress: same-ns + DNS + internet, but not the k8s API.
module "firewall" {
  source           = "../network/firewalls/basic_egress"
  namespace        = var.namespace
  allow_namespaces = [var.namespace]
  allow_internet   = true
}

# Policies union: NGF needs the API for cert generation, so it gets this on top of the
# namespace-wide rules; the arr and data-plane pods stay API-denied.
module "firewall_api" {
  source        = "../network/firewalls/basic_egress"
  namespace     = var.namespace
  policy_name   = "allow-api-egress"
  pod_selector  = { "app.kubernetes.io/name" = "nginx-gateway-fabric" }
  allow_k8s_api = true
}

moved {
  from = module.allow_api
  to   = module.firewall_api
}

# The chart's pre-install/upgrade hook Job can't be reached by the selector above: its pods
# carry only the Job controller's batch labels, so default-deny egress leaves the hook with
# `dial tcp 10.96.0.1:443: i/o timeout` until helm's `wait` times the whole release out
# (seen 2026-09-16 upgrading the media gateway). Second pod-scoped policy for the hook's one
# pod label; the Job name tracks the gateway module's release_name.
module "firewall_api_certgen" {
  source        = "../network/firewalls/basic_egress"
  namespace     = var.namespace
  policy_name   = "allow-api-egress-certgen"
  pod_selector  = { "job-name" = module.gateway.cert_generator_job_name }
  allow_k8s_api = true
}

moved {
  from = module.allow_api_cert_generator
  to   = module.firewall_api_certgen
}

# Ingress: same-namespace, WireGuard clients (they land on the wg-server pod) and non-pod
# external sources only -- every other pod, kube-network included, is denied, so the arr
# ClusterIPs cannot be reached around the outpost. media's LBs are WAN-forwarded, hence
# 0.0.0.0/0 minus the cluster CIDRs. policy_name must differ from module.firewall above.
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

# kube-network's only legitimate ingress is the public gateway proxying to plex (the one
# media app on a shared gateway). Pod-scoped so that data plane cannot reach the
# outpost-protected arr ClusterIPs; the namespace-wide policy above still covers plex's
# LAN paths.
module "firewall_ingress_plex" {
  source       = "../network/firewalls/limited_ingress"
  namespace    = var.namespace
  policy_name  = "namespace-ingress-plex"
  pod_selector = { "app.kubernetes.io/name" = "plex-media-server" }

  allowed_ingress_namespaces = ["kube-network"]
}


