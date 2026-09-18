locals {
  sso_secret = "${var.name}-sso-creds"
  fqdn       = "${var.name}.${var.domain}"

  workflow_sa = "${var.name}-workflow-runner"

  server_service        = "${var.name}-argo-workflows-server"
  admin_cluster_role    = "${var.name}-argo-workflows-admin"
  ui_admin_sa           = "${var.name}-ui-admin"
  ui_admin_token_secret = "${local.ui_admin_sa}.service-account-token"

  helm_values = {
    controller = {
      workflowNamespaces = [var.namespace]
      workflowDefaults = {
        spec = {
          serviceAccountName = local.workflow_sa
        }
      }
    }
    workflow = {
      serviceAccount = {
        create = true
        name   = local.workflow_sa
      }
      rbac = {
        create = true
      }
    }
    server = {
      service = {
        type = "ClusterIP"
      }
      authModes = ["sso"]
      sso = {
        enabled     = true
        issuer      = "https://${var.oauth2_server}/application/o/${var.name}/"
        redirectUrl = "https://${local.fqdn}/oauth2/callback"
        scopes      = ["openid", "profile", "email", "groups"]
        clientId = {
          key  = "client_id"
          name = local.sso_secret
        }
        clientSecret = {
          key  = "secret"
          name = local.sso_secret
        }
        rbac = {
          secretWhitelist = [
            local.sso_secret,
            local.ui_admin_token_secret,
          ]
        }
      }
    }
  }
}
