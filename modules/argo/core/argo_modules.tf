module argocd {
  source = "./argo-cd"
  namespace = var.namespace
  domain = var.domain
  cert_issuer = var.cert_issuer
}

#module argoevents {
#  source = "./argo-events"
#  namespace = var.namespace
#}
