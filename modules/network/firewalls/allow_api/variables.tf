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

# The apiserver's endpoint IPs (control-plane nodes), post-DNAT -- normally read
# from the `kubernetes` Endpoints object by this module (data.tf).
#
# Pass them in when this module sits under a module-level `depends_on`. A
# module-level `depends_on` covers everything inside the module, *data sources
# included*: any pending change in the depended-on module defers this read to
# apply time, the NetworkPolicy then plans a *guessed* peer-block count
# (ClusterIP only = 1), the apply reads the real one (2), and the apply dies
# with "inconsistent final plan" -- `spec.egress[1].to: block count changed
# from 1 to 2`. Reading the endpoints in the caller's ROOT module (nothing
# depends on it there) keeps the peer list known and the plan consistent.
# Putting the read here is what keeps it dynamic; hardcoding control-plane IPs
# instead would trade a loud, retry-converges plan error for a silent 6443
# deny after a re-IP.
#
# null (the default) = read here; nobody else is affected. Callers that own the
# read should always pass the same value, never a filtered subset.
variable "api_peer_ips" {
  type    = list(string)
  default = null
}
