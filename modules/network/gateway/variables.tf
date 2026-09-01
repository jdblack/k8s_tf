# The gateway is instantiated by a caller that already owns the target
# namespace (this module never creates one), so namespace is required.
variable "namespace" {
  type        = string
  description = "Existing namespace to run this Gateway + NGF control plane in (caller must create it)"
}

variable "name" {
  type        = string
  description = "Gateway instance name (namespaced). Also names the cluster-scoped GatewayClass and derives the controller name (gateway.nginx.org/<name>-controller). Every NGF installation must pass a unique value."
}

variable "release_name" {
  type        = string
  default     = "ngf"
  description = "Helm release name for this NGF control plane. Must be unique per namespace so multiple gateway instances can share a namespace (e.g. ngf-public / ngf-private in kube-network)."
}

variable "watch_namespaces" {
  type        = list(string)
  default     = []
  description = "Namespaces this controller watches ([] = watch all). Its own namespace is always included."
}

variable "load_balancer_ip" {
  type        = string
  default     = null
  description = "IP to pin the Gateway data-plane Service to (MetalLB); null lets the LoadBalancer provider assign an IP automatically"
}

variable "routes_namespace" {
  type        = string
  default     = null
  description = "Namespace allowed to attach ListenerSets to this Gateway; null allows any namespace"
}

variable "client_max_body_size" {
  type        = string
  default     = "0"
  description = "Max client request body size for all routes on this Gateway (ClientSettingsPolicy body.maxSize). 0 = unlimited (nginx otherwise defaults to 1m, which 413s large uploads); set e.g. \"100m\" to cap a public-facing gateway."
}

