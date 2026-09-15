# Grafana's authentik OIDC client -- the mantle half; the Secret object is core's.
module "auth" {
  source       = "../../auth/authentik/oidc_provider"
  name         = var.name
  redirect_uri = "https://${var.name}.${var.domain}/login/generic_oauth"

  # dashboard-icons via jsDelivr: Grafana's own icon sits behind a hashed asset path.
  meta_icon       = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/grafana.svg"
  open_in_new_tab = true
}

# Patches the data of the Secret core creates -- never the object, whose lifecycle core
# owns.
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

# grafana.ini (and its $__file{} refs) is read at startup only. Delete pods rather
# than `rollout restart`: a rollout stamps an annotation on the Deployment that core's
# helm release would fight over. The hash trigger keeps steady state a no-op.
resource "terraform_data" "reload" {
  triggers_replace = nonsensitive(sha256("${module.auth.client_id}:${module.auth.client_secret}"))

  provisioner "local-exec" {
    command = "kubectl -n ${var.namespace} delete pod -l app.kubernetes.io/name=${var.name} --ignore-not-found"
  }

  depends_on = [kubernetes_secret_v1_data.oidc]
}
