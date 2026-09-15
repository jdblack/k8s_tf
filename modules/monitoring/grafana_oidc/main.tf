# Grafana's authentik OIDC client -- the mantle half; the Secret object itself is
# created in core.
module "auth" {
  source       = "../../auth/authentik/oidc_provider"
  name         = var.name
  redirect_uri = "https://${var.name}.${var.domain}/login/generic_oauth"

  # dashboard-icons via jsDelivr: Grafana's own icon sits behind a build-hashed
  # asset path.
  meta_icon       = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/grafana.svg"
  open_in_new_tab = true
}

# Patches the data of the Secret OBJECT core creates -- never the object itself,
# whose lifecycle core owns.
resource "kubernetes_secret_v1_data" "oidc" {
  metadata {
    name      = "${var.name}-oidc"
    namespace = var.namespace
  }
  data = {
    client_id     = module.auth.client_id
    client_secret = module.auth.client_secret
  }
}

# Grafana reads grafana.ini (and its $__file{} refs) only at startup, so bounce the
# pod on credential change. Deleting pods rather than `rollout restart` leaves the
# Deployment untouched -- a rollout stamps an annotation on it that core's helm
# release would then fight over.
#
# triggers_replace is a hash, so steady-state applies are a no-op and the secret
# value never lands in state in the clear.
resource "terraform_data" "reload" {
  triggers_replace = nonsensitive(sha256("${module.auth.client_id}:${module.auth.client_secret}"))

  provisioner "local-exec" {
    command = "kubectl -n ${var.namespace} delete pod -l app.kubernetes.io/name=${var.name} --ignore-not-found"
  }

  depends_on = [kubernetes_secret_v1_data.oidc]
}
