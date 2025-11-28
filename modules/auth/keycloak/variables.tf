variable namespace {}
variable name { default = "keycloak" }
variable adminuser { default = "admin" }
variable ingress_class { default  = "private" } 
variable domain {}
variable cert_issuer {}
variable credentials { default = "keycloak-credentials" }

variable helm_repo {  default="https://charts.bitnami.com/bitnami" }
variable chart { default = "keycloak" }

