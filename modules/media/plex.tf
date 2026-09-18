module "plex" {
  source            = "./plex"
  namespace         = var.namespace
  domain            = var.domains["public"]
  cert_issuer       = var.cert_issuer
  plex_claim        = var.plex_claim
  movies_pvc        = var.movies_pvc
  gateway_name      = "public"
  gateway_namespace = "kube-network"
}
