variable "namespace" {
  type        = string
  description = "Existing namespace for the Gateway and its NGF control plane; the caller creates it."
}

# No default: the caller owns the version its CRDs were applied with.
variable "helm_version" {
  type        = string
  description = "nginx-gateway-fabric chart version. Its CRDs are applied by modules/network/api_gateway_config.tf."
}

variable "name" {
  type        = string
  description = "Gateway name (namespaced). Also names the cluster-scoped GatewayClass and derives the controller name gateway.nginx.org/<name>-controller, so it must be unique per installation."
}

variable "release_name" {
  type        = string
  default     = "ngf"
  description = "Helm release name; unique per namespace, so gateways can share one (ngf-public / ngf-private)."
}

variable "watch_namespaces" {
  type        = list(string)
  default     = []
  description = "Namespaces this controller watches; [] = all. Its own namespace is always watched."
}

variable "load_balancer_ip" {
  type        = string
  default     = null
  description = "IP to pin the data-plane Service to (MetalLB); null = the provider assigns one."
}

variable "routes_namespace" {
  type        = string
  default     = null
  description = "Namespace whose ListenerSets may attach to this Gateway; null = any namespace."
}

variable "client_max_body_size" {
  type        = string
  default     = "0"
  description = "ClientSettingsPolicy body.maxSize for every route here. 0 = unlimited; nginx defaults to 1m, which 413s large uploads."
}
