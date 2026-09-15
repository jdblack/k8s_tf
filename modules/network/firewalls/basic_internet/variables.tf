variable "namespace" { type = string }

# Only has to differ when two firewall modules share a namespace.
variable "policy_name" { default = "namespace-firewall" }

variable "network_namespace" { default = "kube-network" }
variable "system_namespace" { default = "kube-system" }
variable "allow_internet" { default = true }
variable "allow_dns" { default = true }
variable "allow_to_ns" { default = true }
variable "allow_to_services" { default = false }

# Carve-out: the apiserver ClusterIP and its endpoint IPs both fall inside
# blocked_egress_cidrs.
variable "allow_to_k8sapi" { default = false }

# Pass these in when this module sits under a module-level `depends_on`, which covers data
# sources too -- the peer count is then guessed at plan and real at apply, and the apply
# dies with "inconsistent final plan". null = read here; see ../allow_api/variables.tf.
variable "api_peer_ips" {
  type    = list(string)
  default = null
}

# kube-proxy SNATs nodePort/remote-backend traffic to a node IP, so the node and LAN
# ranges must be excluded or a workload could trampoline into the LAN.
variable "blocked_egress_cidrs" {
  type        = list(string)
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "169.254.0.0/16"]
  description = "CIDRs excluded from the 0.0.0.0/0 internet egress rule (cluster pod/service ranges + LAN + link-local)."
}

# Each entry becomes its own rule, so it wins over blocked_egress_cidrs.
variable "egress_allow_ip_blocks" {
  type        = list(string)
  default     = []
  description = "Specific CIDRs (e.g. 192.168.0.50/32) that pods may egress to despite blocked_egress_cidrs."
}

# kubernetes.default is the first host of the service CIDR; keep in sync with
# --service-cluster-ip-range.
variable "service_cidr" {
  type    = string
  default = "10.96.0.0/12"
}
