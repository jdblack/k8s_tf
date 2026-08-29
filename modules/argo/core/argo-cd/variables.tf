
variable namespace { type = string }
variable name { default = "argo-cd" }
variable domain { type = string }
variable cert_issuer { type = string } 
variable storage_size { default = "10Gi" }

variable repo { default = "https://argoproj.github.io/argo-helm" }
variable chart { default = "argo-cd" }
