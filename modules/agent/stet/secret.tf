locals {
  has_hands_identity = var.hands_identity != "" && fileexists(pathexpand(var.hands_identity_file))
}

# THE SELF'S CREDENTIALS, IN THE GRAPH.
#
# ★ WHY THIS IS TERRAFORM AND NOT A HAND-CREATED SECRET: a greenfield apply must be ONE apply. The hands
# pod reads both values as REQUIRED env, so a room whose Secret arrives after the apply leaves the pod
# in CreateContainerConfigError and the deployment's rollout never completes — the apply hangs, and a
# hanging apply is how you end up applying in pieces (which is exactly what happened on 2026-10-17).
#
# ★ THE VALUES COME FROM FILES, NOT FROM tfvars: the model key already lives in
# `~/.cline/secrets/` (600, never in a repo), so there is nothing to duplicate and nothing to pass.
# ★ THEY DO LAND IN STATE. That is the price of an atomic apply; the state is itself a Secret in
# kube-system, protected exactly like the key. `ignore_changes` on `data` means a later ROTATION is an
# out-of-band operation: change the file, `kubectl delete secret`, re-apply — Terraform will not fight
# you, and will not need the old value it happened to remember.
resource "kubernetes_secret_v1" "credentials" {
  metadata {
    name      = var.secret_name
    namespace = kubernetes_namespace_v1.room.metadata[0].name
  }

  type = "Opaque"

  data = merge(
    {
      (var.model_key_field)  = trimspace(file(pathexpand(var.model_key_file)))
      (var.door_token_field) = trimspace(file(pathexpand(var.door_token_file)))
    },
    # ★ THE FINGER'S PROOF, when the box has one. Optional on purpose: `file()` on a missing path
    # fails the WHOLE plan, and a self that has not minted `hands` yet should not be un-appliable.
    # Without it the pod fails at CreateContainerConfigError — loud, and no silent anonymous writes.
    local.has_hands_identity ? {
      handsIdentitySecret = trimspace(file(pathexpand(var.hands_identity_file)))
    } : {}
  )

  lifecycle {
    ignore_changes = [data]
  }
}
