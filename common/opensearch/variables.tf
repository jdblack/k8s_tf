variable namespace { default=null }
variable name { default = null } 
variable domain  {}
variable cert_issuer {}
variable lbtype { default="ClusterIP"} 
variable singlenode { default= null}
variable replicas { default= 3 }

variable TLSforLB {
  default=true
  type = bool
  description = "Should the Load Balancer use TLS or not"
}


locals {
  name = coalesce(var.name, var.namespace)
  fqdn = var.domain
}
