# Bootstrap credentials for the chart's pre-install register Job, which reads these three env
# names. Keeping them in a Secret (rather than helm values) keeps the token out of the values
# blob; `existingInitSecret` points the Job here.
resource "kubernetes_secret_v1" "registration" {
  metadata {
    name      = "${var.name}-registration"
    namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  }

  data = {
    CONFIG_NAME     = var.registration_name
    CONFIG_INSTANCE = var.instance_url
    CONFIG_TOKEN    = var.registration_token
  }
}
