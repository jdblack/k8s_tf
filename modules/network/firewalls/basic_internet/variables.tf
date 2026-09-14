variable "namespace" { type = string }

# The NetworkPolicy name within the namespace. Namespaced, so it only needs to
# differ when multiple firewall modules target the same namespace (e.g. a
# namespace-wide egress policy plus a pod-scoped one).
variable "policy_name" { default = "namespace-firewall" }

variable "network_namespace" { default = "kube-network" }
variable "system_namespace" { default = "kube-system" }
variable "allow_internet" { default = true }
variable "allow_dns" { default = true }
variable "allow_to_ns" { default = true }
variable "allow_to_services" { default = false }

# Allow pods to reach the Kubernetes API server (kubernetes.default.svc ClusterIP
# + the apiserver's real endpoint IPs). Both fall inside blocked_egress_cidrs, so
# they need explicit carve-out rules. Used by workloads like the NGF
# cert-generator/controller.
variable "allow_to_k8sapi" { default = false }

# Private / RFC1918 ranges pods may NOT egress to. Keeps a compromised workload
# from trampolining into cluster nodes, nodePorts/LBs or the LAN: kube-proxy SNATs
# nodePort/remote-backend service traffic, which would bypass the pod-IP
# restrictions, so the node/LAN ranges must be excluded at the pre-DNAT destination
# too.
variable "blocked_egress_cidrs" {
  type        = list(string)
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "169.254.0.0/16"]
  description = "CIDRs excluded from the 0.0.0.0/0 internet egress rule (cluster pod/service ranges + LAN + link-local)."
}

# Explicit carve-outs, e.g. a specific LAN tuner/NAS a workload must reach.
# Each entry becomes its own egress allow rule, so it wins over the exclusions.
variable "egress_allow_ip_blocks" {
  type        = list(string)
  default     = []
  description = "Specific CIDRs (e.g. 192.168.0.50/32) that pods may egress to despite blocked_egress_cidrs."
}

# The cluster's service CIDR; the `kubernetes.default` ClusterIP is its first host
# (10.96.0.1 by default) -- derived via cidrhost, not hardcoded. Keep in sync with
# the apiserver's --service-cluster-ip-range.
variable "service_cidr" {
  type    = string
  default = "10.96.0.0/12"
}
