locals {
  sso_secret = "${var.name}-sso-creds"
  fqdn       = "${var.name}.${var.domain}"

  # ServiceAccount workflow pods run under.  It is created by the chart from
  # the `workflow.serviceAccount` block below; the chart also creates the
  # namespaced Role + RoleBinding (create/patch on workflowtaskresults) that the
  # emissary executor needs.  We only have to point workflowDefaults at it.
  workflow_sa = "${var.name}-workflow-runner"

  # Resource names the chart renders from the release fullname
  # (<release>-argo-workflows-*); the HTTPRoute backend, the SSO RBAC target
  # ClusterRole and the UI-admin SA/token secret below all bind to these.  Keep
  # them in lockstep with the chart version pin (helm.tf) -- they only move when
  # the chart changes them.
  server_service        = "${var.name}-argo-workflows-server"
  admin_cluster_role    = "${var.name}-argo-workflows-admin"
  ui_admin_sa           = "${var.name}-ui-admin"
  ui_admin_token_secret = "${local.ui_admin_sa}.service-account-token"

  # Namespace-local copy of the private-CA ConfigMap that cert_manager keeps in
  # the `default` namespace (name = cert_issuer); oauth2.tf mirrors it here so
  # the server pod can mount it (ConfigMap volumes are same-namespace only).
  ca_cert_cm = "${var.name}-ca-cert"

  helm_values = {
    controller = {
      # Run workflow pods under the dedicated runner SA instead of the namespace
      # default SA.
      workflowDefaults = {
        spec = {
          serviceAccountName = local.workflow_sa
        }
      }
      # Only create the runner SA + Role/RoleBinding in this namespace.  If
      # workflows should also run in other namespaces, add them here.
      workflowNamespaces = [var.namespace]
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
      # Mount the private CA cert (mirrored into this namespace by oauth2.tf)
      # so the server can validate the TLS cert of the Authentik SSO issuer.
      # Chart 0.46.x / app 3.7 has no `server.sso.rootCA` knob yet -- this file
      # mount is the stand-in.  Replace it with `server.sso.rootCA` when moving
      # to chart >= 1.x / app >= v4: rootCA *augments* the trust store, whereas
      # this subPath mount *replaces* the container's CA bundle file (so the
      # server would lose public roots it might need for other outbound TLS).
      volumes = [
        {
          name = "ca-certs"
          configMap = {
            name = kubernetes_config_map_v1.local_ca_mirror.metadata[0].name
          }
        }
      ]
      volumeMounts = [
        {
          name      = "ca-certs"
          mountPath = "/etc/ssl/certs/ca-certificates.crt"
          subPath   = "tls.crt"
        }
      ]
      service = {
        type = "ClusterIP"
      }
      authModes = ["sso"]
      sso = {
        enabled = true
        issuer  = "https://${var.oauth2_server}/application/o/${var.name}/"
        scopes  = ["openid", "profile", "email", "groups"]
        clientId = {
          key  = "client_id"
          name = local.sso_secret
        }
        clientSecret = {
          key  = "secret"
          name = local.sso_secret
        }
        rbac = {
          # The chart grants the server `get` on secrets cluster-wide when SSO
          # RBAC is on; restrict it to the two secrets it actually reads: the
          # SSO client credentials (oauth2.tf) and the UI-admin SA token secret
          # (ui_admin_access.tf).  K8s >= 1.24 needs that token secret created
          # explicitly, so it also has to be listed here.
          secretWhitelist = [
            local.sso_secret,
            local.ui_admin_token_secret,
          ]
        }
      }
    }
  }
}