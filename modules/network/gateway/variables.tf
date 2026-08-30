variable "namespace" {
  type    = string
  default = "nginx-gateway"
}

variable "gateway_name" {
  type    = string
  default = "media-private"
}

variable "gateway_class" {
  type    = string
  default = "nginx"
}

variable "load_balancer_ip" {
  type        = string
  default     = "192.168.0.106"
  description = "IP to pin the Gateway data-plane Service to (MetalLB)"
}

variable "domain" {
  type        = string
  description = "Internal DNS domain used for the :80 wildcard listener"
}

variable "routes_namespace" {
  type        = string
  default     = "media"
  description = "Namespace allowed to attach HTTPRoutes to the :80 listener and ListenerSets to this Gateway"
}
