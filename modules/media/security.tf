
# The NGF control plane lives IN the media namespace (api_gateway.tf). Its
# cert-generator job and controller must reach the Kubernetes API server; the
# basic_internet firewall module now handles that carve-out natively via the
# allow_to_k8sapi flag (the ClusterIP and control-plane endpoint IPs are inside
# its blocked_egress_cidrs ranges, so they need explicit rules).
module "firewall" {
  source            = "../network/firewalls/basic_internet"
  namespace         = var.namespace
  allow_to_services = false
  allow_to_k8sapi   = true
}

