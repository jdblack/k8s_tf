variable "namespace" { type = string }

# NetworkPolicy name within the namespace: only has to differ when two firewall
# modules target the same namespace (see basic_internet/variables.tf).
variable "policy_name" { default = "allow-api-egress" }

# Pods this policy applies to (NetworkPolicy podSelector).
variable "pod_selector" {
  type        = map(string)
  description = "Labels selecting the pods allowed to reach the Kubernetes API server, e.g. { \"app.kubernetes.io/name\" = \"nginx-gateway-fabric\" }."
}

# The API server is reached by name (kubernetes.default.svc, resolved via cluster
# DNS), so the pods usually need DNS egress too.
variable "allow_dns" { default = true }

variable "system_namespace" { default = "kube-system" }

# The `kubernetes.default` ClusterIP is the first host of the service CIDR.
variable "service_cidr" {
  type    = string
  default = "10.96.0.0/12"
}

# Normally read from the `kubernetes` Endpoints object by this module (data.tf).
# Pass them in when this module sits under a module-level `depends_on`: that
# covers data sources too, so a pending change in the depended-on module defers
# the read to apply time, the NetworkPolicy's peer-block count is then guessed at
# plan and real at apply, and the apply dies with "inconsistent final plan"
# (`spec.egress[1].to: block count changed from 1 to 2`). Reading the endpoints
# in the caller's ROOT module keeps the peer list known.
#
# null (the default) = read here. Callers that own the read should always pass
# the same value, never a filtered subset.
variable "api_peer_ips" {
  type    = list(string)
  default = null
}
