locals {
  helm_values = {
    grafana = {
      enabled = true
      "grafana.ini" = {
        # Explicit public URL -- Grafana builds the OAuth redirect_uri from
        # root_url, and authentik's allowed redirect URI is matched strictly.
        server = {
          root_url = "https://${var.grafana_name}.${var.domain}/"
        }
        # SSO-only UI: the password form is hidden, so Authentik is the only way
        # to log in. Basic auth stays ENABLED on purpose -- the chart's
        # dashboard/datasource sidecars authenticate with it (REQ_USERNAME/
        # REQ_PASSWORD from the release's admin secret) to call Grafana's
        # provisioning reload API. Disabling it 401s the sidecars and kills
        # hot-reload.
        auth = {
          disable_login_form = true
        }
        "auth.generic_oauth" = {
          enabled       = true
          name          = "Authentik"
          allow_sign_up = true
          scopes        = "openid profile email groups"
          # The client credentials are provisioned by the mantle stack (which
          # owns the authentik oidc_provider + the `<name>-oidc` secret); the
          # $__file{} references are resolved by Grafana at startup only.
          client_id            = "$__file{/etc/secrets/auth-generic-oauth/client_id}"
          client_secret        = "$__file{/etc/secrets/auth-generic-oauth/client_secret}"
          auth_url             = "https://auth.${var.domain}/application/o/authorize/"
          token_url            = "https://auth.${var.domain}/application/o/token/"
          api_url              = "https://auth.${var.domain}/application/o/userinfo/"
          signout_redirect_url = "https://auth.${var.domain}/application/o/${var.grafana_name}/end-session/"
          # Members of the authentik `<name>-admin` group get Grafana Admin,
          # everyone else Viewer. Non-strict, so a missing groups claim falls
          # back to the org role instead of denying login.
          role_attribute_path = "contains(groups[*], '${var.grafana_name}-admin') && 'Admin' || 'Viewer'"
        }
      }
      persistence = {
        enabled = true
        size    = "1Gi"
      }
      # The Grafana PVC is Longhorn RWO. With the chart's default RollingUpdate,
      # a roll that lands the new pod on a different node deadlocks: the new pod
      # can't attach the volume while the old pod still holds it, and the old
      # pod isn't terminated until the new one is Ready. Recreate terminates the
      # old pod first, so the volume is never double-attached.
      deploymentStrategy = {
        type = "Recreate"
      }
      # Trust the private CA that signs authentik's TLS cert. Grafana is Go, so
      # SSL_CERT_FILE is read in addition to the system cert directory (public
      # roots stay trusted where the image ships them).
      env = {
        SSL_CERT_FILE = "/etc/grafana/certs/tls.crt"
      }
      extraConfigmapMounts = [{
        name      = "${var.grafana_name}-ca"
        configMap = kubernetes_config_map_v1.grafana_ca.metadata[0].name
        mountPath = "/etc/grafana/certs"
        readOnly  = true
      }]
      extraSecretMounts = [{
        name       = "${var.grafana_name}-oidc"
        secretName = "${var.grafana_name}-oidc"
        mountPath  = "/etc/secrets/auth-generic-oauth"
        readOnly   = true
      }]
    }
    prometheus = {
      prometheusSpec = {
        podMonitorSelectorNilUsesHelmValues     = false
        serviceMonitorSelectorNilUsesHelmValues = false
      }
    }
  }
}
