locals {
  ollama_endpoint = try(module.ollama[0].endpoint, null)

  # Gated on the endpoint existing: a plan that has not built ollama yet must not point the app
  # at nothing.
  ai_config = local.ollama_endpoint == null ? {} : {
    PAPERLESS_AI_ENABLED               = "true"
    PAPERLESS_AI_LLM_BACKEND           = "ollama"
    PAPERLESS_AI_LLM_ENDPOINT          = local.ollama_endpoint
    PAPERLESS_AI_LLM_MODEL             = var.llm_model
    PAPERLESS_AI_LLM_CONTEXT_SIZE      = tostring(var.ai_context_size)
    PAPERLESS_AI_LLM_REQUEST_TIMEOUT   = tostring(var.ai_request_timeout)
    PAPERLESS_AI_LLM_OUTPUT_LANGUAGE   = var.ai_output_language
    PAPERLESS_AI_LLM_EMBEDDING_BACKEND = "ollama"
    PAPERLESS_AI_LLM_EMBEDDING_MODEL   = var.embedding_model
    PAPERLESS_LLM_INDEX_TASK_CRON      = var.ai_index_cron
  }

  paperless_config = merge(
    {
      PAPERLESS_URL                  = "https://${local.fqdn}"
      PAPERLESS_ALLOWED_HOSTS        = local.fqdn
      PAPERLESS_CSRF_TRUSTED_ORIGINS = "https://${local.fqdn}"

      PAPERLESS_REDIS = "redis://${module.valkey.host}:${module.valkey.port}"

      PAPERLESS_APPS                                = "allauth.socialaccount.providers.openid_connect"
      PAPERLESS_SOCIAL_AUTO_SIGNUP                  = "true"
      PAPERLESS_SOCIAL_ACCOUNT_SYNC_GROUPS          = "true"
      PAPERLESS_SOCIAL_ACCOUNT_SYNC_SUPERUSER_GROUP = "paperless-admin"
    },
    local.ai_config,
  )

  # The client secret is in here, so this map lands in the secret rather than the config map.
  paperless_secret = {
    PAPERLESS_SOCIALACCOUNT_PROVIDERS = jsonencode({
      openid_connect = {
        # 'groups' is what carries paperless-admin and paperless-user across.
        SCOPE = ["openid", "profile", "email", "groups"]

        APPS = [{
          provider_id = "authentik"
          name        = "Authentik"
          client_id   = module.auth.client_id
          secret      = module.auth.client_secret

          settings = {
            # No trailing slash: allauth appends /.well-known/openid-configuration to this.
            server_url        = "https://auth.${var.domain}/application/o/${var.name}"
            token_auth_method = "client_secret_post"
          }
        }]
      }
    })
  }
}

module "paperless" {
  source = "./paperless"

  namespace = kubernetes_namespace_v1.this.metadata[0].name
  name      = var.name
  hostname  = local.fqdn

  image     = var.image
  image_tag = var.image_tag

  port           = local.app_port
  flower_port    = local.flower_port
  flower_enabled = var.enable_flower

  data_pvc    = kubernetes_persistent_volume_claim_v1.data.metadata[0].name
  media_pvc   = kubernetes_persistent_volume_claim_v1.media.metadata[0].name
  consume_pvc = kubernetes_persistent_volume_claim_v1.consume.metadata[0].name

  admin_user = var.admin_user
  admin_mail = var.admin_mail

  time_zone       = var.time_zone
  ocr_language    = var.ocr_language
  ocr_languages   = var.ocr_languages
  filename_format = var.filename_format

  extra_config = local.paperless_config
  extra_secret = local.paperless_secret
}
