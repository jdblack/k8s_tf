variable "namespace" { type = string }

# NetworkPolicy name within the namespace. Must be unique per namespace, so if
# this module is used alongside basic_internet (the usual pattern) it needs a
# different name from that module's policy.
variable "policy_name" { default = "allow-api-egress" }

# Pods this policy applies to (NetworkPolicy podSelector). Only pods matching
# ALL of these labels may egress to the Kubernetes API server.
variable "pod_selector" {
  type        = map(string)
  description = "Labels selecting the pods allowed to reach the Kubernetes API server, e.g. { \"app.kubernetes.io/name\" = \"nginx-gateway-fabric\" }."
}

# The API server hostname (kubernetes.default.svc) is resolved via cluster DNS
# before the connection is made, so the targeted pods usually need DNS egress
# too. Disable only when the namespace-wide policy already covers DNS.
variable "allow_dns" { default = true }

variable "system_namespace" { default = "kube-system" }

# The cluster's service CIDR; the `kubernetes.default` ClusterIP is its first
# host (10.96.0.1 by default) -- derived via cidrhost rather than hardcoded.
variable "service_cidr" {
  type    = string
  default = "10.96.0.0/12"
}
