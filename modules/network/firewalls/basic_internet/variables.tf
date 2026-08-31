variable "namespace" { type = string }
variable "network_namespace" { default = "kube-network" }
variable "system_namespace" { default = "kube-system" }
variable "allow_internet" { default = true }
variable "allow_dns" { default = true }
variable "allow_to_ns" { default = true }
variable "allow_to_services" { default = false }

# Allow pods to reach the Kubernetes API server (kubernetes.default.svc ClusterIP
# + the apiserver's real endpoint IPs). The ClusterIP (10.0.0.0/8) and the
# control-plane node IPs (192.168.0.0/16) fall inside blocked_egress_cidrs, so
# they need explicit carve-out rules. Used by workloads like the NGF
# cert-generator/controller.
variable "allow_to_k8sapi" { default = false }

# Private / RFC1918 ranges that pods may NOT egress to. This is what keeps a
# compromised workload from trampolining into cluster nodes, nodePorts/LBs, or
# the LAN: kube-proxy SNATs nodePort/remote-backend service traffic, which
# would otherwise bypass the pod-IP restrictions, so the node/LAN ranges must
# be excluded at the pre-DNAT destination too.
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
