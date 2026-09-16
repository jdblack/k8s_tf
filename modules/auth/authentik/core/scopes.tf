# The API key Terraform itself uses to manage authentik, deployed as the blueprint Secret
# the chart loads (see `locals.blueprints`; the key is also kept as `api_key` for hand use).
#
# Deliberately NOT AUTHENTIK_BOOTSTRAP_TOKEN/_PASSWORD: those only feed
# core/setup/signals.py's bootstrap, which is gated on `not Setup.get(tenant=tenant)` --
# once per instance, on a fresh install. A running instance ignores them, so rotating the
# key that way would mean flipping the Setup row by hand in the DB, and the token would sit
# in chart values either way.
resource "kubernetes_secret_v1" "blueprint_deploy_key" {
  metadata {
    name      = "${var.name}-tfdeploykey"
    namespace = var.namespace
  }
  data = {
    api_key = random_password.terraform_key.result
    "terraform.yaml" = templatefile("${path.module}/api_key.tftpl",
      {
        key = random_password.terraform_key.result
    })
  }
}
