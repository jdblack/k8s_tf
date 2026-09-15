variable "namespace" { type = string }

# Only has to differ when two firewall modules share a namespace.
variable "policy_name" { default = "allow-api-egress" }

# Pods this policy applies to.
variable "pod_selector" {
  type        = map(string)
  description = "Labels of the pods allowed to reach the API server, e.g. { \"app.kubernetes.io/name\" = \"nginx-gateway-fabric\" }."
}

# The API is reached by name, so the pods usually need DNS too.
variable "allow_dns" { default = true }

variable "system_namespace" { default = "kube-system" }

# kubernetes.default is the first host of the service CIDR.
variable "service_cidr" {
  type    = string
  default = "10.96.0.0/12"
}

# Pass these in when this module sits under a module-level `depends_on`, which covers data
# sources too: the peer-block count is then guessed at plan and real at apply (e.g.
# `spec.egress[1].to: block count changed from 1 to 2`) and the apply dies with "inconsistent
# final plan". Reading them in the caller's root keeps the list known.
#
# null (default) = read here. Callers that own the read pass the same value, never a subset.
variable "api_peer_ips" {
  type    = list(string)
  default = null
}
