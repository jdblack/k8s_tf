
module argocd {
  source = "../../service_modules/argocd"
}

output "argo_pass" {
  value = module.argocd.admin_pass
  sensitive=true
}
