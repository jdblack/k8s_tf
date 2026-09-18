module "auth" {
  source       = "../../auth/authentik/oidc_provider"
  name         = var.name
  redirect_uri = "https://${var.name}.${var.domain}/login/generic_oauth"

  meta_icon       = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/grafana.svg"
  open_in_new_tab = true
}

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

resource "terraform_data" "reload" {
  triggers_replace = nonsensitive(sha256("${module.auth.client_id}:${module.auth.client_secret}"))

  provisioner "local-exec" {
    command = "kubectl -n ${var.namespace} delete pod -l app.kubernetes.io/name=${var.name} --ignore-not-found"
  }

  depends_on = [kubernetes_secret_v1_data.oidc]
}
