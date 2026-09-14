locals {
  sso_secret = "${var.name}-sso-creds"
  fqdn       = "${var.name}.${var.domain}"

  # Workflow pods' SA. The chart creates it (plus the namespaced Role/
  # RoleBinding the emissary executor needs); we only point workflowDefaults at it.
  workflow_sa = "${var.name}-workflow-runner"

  # Chart-rendered resource names (<release>-argo-workflows-*): the HTTPRoute
  # backend, the SSO ClusterRole and the UI-admin SA/token secret all bind to
  # these. They only move when the chart pin (helm.tf) does.
  server_service        = "${var.name}-argo-workflows-server"
  admin_cluster_role    = "${var.name}-argo-workflows-admin"
  ui_admin_sa           = "${var.name}-ui-admin"
  ui_admin_token_secret = "${local.ui_admin_sa}.service-account-token"

  # Namespace-local copy of cert_manager's private-CA ConfigMap (ConfigMap
  # volumes are same-namespace only); oauth2.tf mirrors it here.
  ca_cert_cm = "${var.name}-ca-cert"

  helm_values = {
    controller = {
      # Only create the runner SA + Role/RoleBinding in this namespace. If
      # workflows should run elsewhere, add those namespaces here.
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
      # Mount the private CA (mirrored into this namespace by oauth2.tf) so the
      # server can validate the Authentik issuer's TLS cert. Chart 0.46.x has no
      # `server.sso.rootCA` knob yet; when moving to chart >= 1.x / app >= v4,
      # replace this mount with rootCA -- it AUGMENTS the trust store, whereas
      # this subPath mount REPLACES the container's CA bundle.
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
        # Gate TLS terminates, so the server runs --secure=false and cannot
        # infer the scheme: left empty it builds redirect_uri with proto=http,
        # and the provider (matching_mode=strict) rejects the authorize request,
        # so login never completes. Pin it.
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
          # SSO RBAC otherwise grants the server cluster-wide `get` on secrets;
          # restrict it to the two it actually reads -- the SSO client
          # credentials (oauth2.tf) and the UI-admin SA token (K8s >= 1.24 needs
          # that token secret created explicitly, hence listing it).
          secretWhitelist = [
            local.sso_secret,
            local.ui_admin_token_secret,
          ]
        }
      }
    }
  }
}