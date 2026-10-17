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

  # The mailbox is the SELF, not the hand: `stet`, not `stet-hand`.
  mail_me = var.name

  secret_name = var.secret_name
  image_tag   = var.hands_image_tag
  activities  = var.activities

  # ★ The finger writes AS the self. Without this it writes as `anonymous`, and the store's
  # `ELLMEPHANT_LEASERS=hands` then refuses every lease it takes — PROTECTED work becomes unreachable
  # from a bell. The proof lives in `var.secret_name` under `handsIdentitySecret`.
  identity = var.hands_identity

  # ★ THE CUTOVER. With this set the hand stops reading the image's baked home and reads the claim:
  # `bin/` and `dist/` come from the self's files, so a code change is a file change, not a rebuild.
  home_claim = kubernetes_persistent_volume_claim_v1.home.metadata[0].name

  depends_on = [module.brain]
}
