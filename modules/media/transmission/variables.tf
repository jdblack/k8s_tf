variable namespace { type = string }
variable name { default = "transmission" }

variable helm_repo { default = "oci://ghcr.io/lexfrei/charts" }
variable chart { default = "transmission" }

variable cert_issuer { type = string }
variable ingress_class { type = string } 
variable domain { type = string } 

variable movies_pvc { type = string }
