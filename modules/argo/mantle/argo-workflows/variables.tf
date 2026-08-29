
variable namespace     { type = string }
variable name          { default = "argo-wf" }

variable repo { default = "https://argoproj.github.io/argo-helm" }
variable chart { default = "argo-workflows" }

variable domain {}
variable cert_issuer { type = string }

variable sso_server {}
