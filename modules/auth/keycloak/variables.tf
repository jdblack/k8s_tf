variable namespace {}
variable name { default = "keycloak" }
variable adminuser { default = "admin" }
variable ingress_class { default  = "private" } 
variable domain {}
variable cert_issuer {}
variable credentials { default = "keycloak-credentials" }

variable helm_repo {  default="oci://registry-1.docker.io/bitnamicharts" }
variable chart { default = "keycloak" }

