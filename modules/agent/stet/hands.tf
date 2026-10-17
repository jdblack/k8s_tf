locals {
  # ★ THE PRIZE OF THE MOVE, expressed as one line: the hand reaches the brain over a same-namespace
  # ClusterIP. No gateway hop, no cross-namespace egress rule, no post-DNAT selector — the plumbing
  # that cline-home needed to let a pod talk to `mcp` does not exist here, because it is not needed.
  brain_url = "http://${var.name}.${var.namespace}.svc.cluster.local:8888/mcp"
  sel       = { "app.kubernetes.io/name" = "ellmephant", "app.kubernetes.io/instance" = var.name }
}

module "hands" {
  source = "../hands"

  namespace = kubernetes_namespace_v1.room.metadata[0].name
  name      = "${var.name}-hand"
  domain    = var.domain

  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
  expose            = var.hands_expose

  brain_url = local.brain_url

  secret_name = var.secret_name
  image_tag   = var.hands_image_tag
  activities  = var.activities

  depends_on = [module.brain]
}
