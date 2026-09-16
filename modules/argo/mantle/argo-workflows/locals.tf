locals {
  sso_secret = "${var.name}-sso-creds"
  fqdn       = "${var.name}.${var.domain}"

  # Chart creates this SA plus the namespaced Role/RoleBinding; we only point workflowDefaults at it.
  workflow_sa = "${var.name}-workflow-runner"

  # Chart-rendered names: they only move with the chart pin (helm.tf).
  server_service        = "${var.name}-argo-workflows-server"
  admin_cluster_role    = "${var.name}-argo-workflows-admin"
  ui_admin_sa           = "${var.name}-ui-admin"
  ui_admin_token_secret = "${local.ui_admin_sa}.service-account-token"

  helm_values = {
    controller = {
      # The runner SA and its Role only exist in this namespace.
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
        enabled = true
        issuer  = "https://${var.oauth2_server}/application/o/${var.name}/"
        # TLS ends at the gateway and the server runs --secure=false, so it cannot infer the scheme:
        # left empty it builds proto=http, which the strict provider rejects. Pin it.
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
          # Without this the SSO RBAC grants cluster-wide `get` on secrets; restrict it to the two the
          # server reads (SSO creds, UI-admin token).
          secretWhitelist = [
            local.sso_secret,
            local.ui_admin_token_secret,
          ]
        }
      }
    }
  }
}