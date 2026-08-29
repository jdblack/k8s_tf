

variable argo_namespace { default = "argo" }
variable argo_auth_secret { default = "argocd-initial-admin-secret" }
variable argo_cd_server { default = "" }
variable deployment { type = any }

variable ai_namespace { default = "ai" }
variable ai_create_namespace { default = true }
variable ai_deployer_repo { default = "git@github.com:jdblack/argo-linuxguru.git" }
variable ai_deployer_path { default = "deployments/ai" }
variable ai_argo_namespace { default = "argo" }

