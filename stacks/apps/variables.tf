variable "argo_namespace" { default = "argo" }
variable "argo_auth_secret" { default = "argocd-initial-admin-secret" }
variable "argo_cd_server" { default = "" }
variable "deployment" { type = any }

variable "ai_namespace" { default = "ai" }
variable "ai_create_namespace" { default = true }
variable "ai_deployer_repo" { default = "git@github.com:jdblack/argo-linuxguru.git" }
variable "ai_deployer_path" { default = "deployments/ai" }
variable "ai_argo_namespace" { default = "argo" }

# Intel GPU device plugin. The project is "gpu" (giving AppProject gpu + Application
# aoa-gpu) while the plugin itself runs in kube-gpu, which is the namespace the child
# Application creates and the only one the project's destination rule allows besides argo.
variable "gpu_project" { default = "gpu" }
variable "gpu_namespace" { default = "kube-gpu" }
variable "gpu_create_namespace" { default = false }
variable "gpu_deployer_repo" { default = "git@github.com:jdblack/argo-linuxguru.git" }
variable "gpu_deployer_path" { default = "deployments/gpu" }
variable "gpu_argo_namespace" { default = "argo" }
