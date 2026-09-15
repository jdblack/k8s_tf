variable "namespace" { type = string }

# Namespaced, so it only has to differ when several firewall modules target the
# same namespace (a namespace-wide policy plus a pod-scoped one).
variable "policy_name" { default = "namespace-firewall" }

variable "network_namespace" { default = "kube-network" }
variable "system_namespace" { default = "kube-system" }
variable "allow_internet" { default = true }
variable "allow_dns" { default = true }
variable "allow_to_ns" { default = true }
variable "allow_to_services" { default = false }

# Carve-out from blocked_egress_cidrs: the API server is reachable via the
# kubernetes.default.svc ClusterIP and the apiserver's endpoint IPs, both of which
# fall inside those exclusions. Used by workloads like the NGF cert-generator.
variable "allow_to_k8sapi" { default = false }

# The apiserver's endpoint IPs (control-plane nodes), post-DNAT -- normally read
# from the `kubernetes` Endpoints object by this module (data.tf). Pass them in
# when this module sits under a module-level `depends_on`, which covers data
# sources too: a pending change in the depended-on module otherwise defers the
# read to apply time, the peer-block count is then guessed at plan and real at
# apply, and the apply dies with "inconsistent final plan". See the identical
# variable in ../allow_api/variables.tf for the full mechanism.
variable "api_peer_ips" {
  type    = list(string)
  default = null
}

# Private ranges pods may NOT egress to. kube-proxy SNATs nodePort/remote-backend
# traffic to a node IP, so the node/LAN ranges have to be excluded from the
# 0.0.0.0/0 rule or a compromised workload could trampoline into the LAN.
variable "blocked_egress_cidrs" {
  type        = list(string)
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "169.254.0.0/16"]
  description = "CIDRs excluded from the 0.0.0.0/0 internet egress rule (cluster pod/service ranges + LAN + link-local)."
}

# Explicit carve-outs, e.g. a specific LAN tuner/NAS. Each entry becomes its own
# egress rule, so it wins over the exclusions.
variable "egress_allow_ip_blocks" {
  type        = list(string)
  default     = []
  description = "Specific CIDRs (e.g. 192.168.0.50/32) that pods may egress to despite blocked_egress_cidrs."
}

# The `kubernetes.default` ClusterIP is the first host of the service CIDR. Keep
# in sync with the apiserver's --service-cluster-ip-range.
variable "service_cidr" {
  type    = string
  default = "10.96.0.0/12"
}
