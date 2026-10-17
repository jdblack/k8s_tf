locals {
  # ★ THE PRIZE OF THE MOVE, expressed as one line: the hand reaches the brain over a same-namespace
  # ClusterIP. No gateway hop, no cross-namespace egress rule, no post-DNAT selector — the plumbing
  # that cline-home needed to let a pod talk to `mcp` does not exist here, because it is not needed.
  brain_service = "${var.name}-brain"
  brain_url     = "http://${local.brain_service}.${var.namespace}.svc.cluster.local:8888/mcp"
  # `instance` is the RELEASE name = the self, because the backup schedule drags the claim in by the
  # pod it mounts on, and "whose" is the question a selector should answer.
  sel = { "app.kubernetes.io/name" = "ellmephant", "app.kubernetes.io/instance" = var.name }
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
