module "argocd" {
  source      = "./argo-cd"
  namespace   = var.namespace
  domain      = var.domain
  cert_issuer = var.cert_issuer
}
