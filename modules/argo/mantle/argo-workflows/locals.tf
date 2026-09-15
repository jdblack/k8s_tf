locals {
  sso_secret = "${var.name}-sso-creds"
  fqdn       = "${var.name}.${var.domain}"

  # Workflow pods' SA: the chart creates it and the namespaced Role/RoleBinding the
  # emissary executor needs; we only point workflowDefaults at it.
  workflow_sa = "${var.name}-workflow-runner"

  # Chart-rendered names: the HTTPRoute backend, the SSO ClusterRole and the UI-admin
  # SA/token secret all bind to these, so they only move with the chart pin (helm.tf).
  server_service        = "${var.name}-argo-workflows-server"
  admin_cluster_role    = "${var.name}-argo-workflows-admin"
  ui_admin_sa           = "${var.name}-ui-admin"
  ui_admin_token_secret = "${local.ui_admin_sa}.service-account-token"

  helm_values = {
    controller = {
      # The runner SA + Role/RoleBinding are only created here; workflows running in
      # another namespace would need that namespace listed too.
      workflowNamespaces = [var.namespace]
      # Run workflow pods under the runner SA, not the namespace default.
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
        # The gateway terminates TLS, so the server runs --secure=false and cannot infer
        # the scheme: left empty it builds redirect_uri with proto=http, which the
        # provider (matching_mode=strict) rejects, so login never completes. Pin it.
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
          # Without this the SSO RBAC grants the server cluster-wide `get` on secrets.
          # Restrict it to the two it reads: the SSO client credentials (oauth2.tf) and
          # the UI-admin SA token (created explicitly, and listed here so it is
          # readable).
          secretWhitelist = [
            local.sso_secret,
            local.ui_admin_token_secret,
          ]
        }
      }
    }
  }
}