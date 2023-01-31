locals {
  config = {
    grafana = {
      "grafana.ini" = {
        "auth.generic_oauth" = {
          enabled= true
          oauth_auto_login = true
          tls_skip_verify_insecure = true
          name="Keycloak"
          allow_sign_up= true
          scopes = "openid email profile roles"
          auth_url= "${var.keycloak_domain}/realms/${var.keycloak_realm}/protocol/openid-connect/auth"
          token_url= "${var.keycloak_domain}/realms/${var.keycloak_realm}/protocol/openid-connect/token"
          api_url= "${var.keycloak_domain}/realms/${var.keycloak_realm}/protocol/openid-connect/userinfo"
          client_id= var.name
          client_secret = random_password.client_pass.result
          role_attribute_path = "groups[?contains(@, '/grafana-admin') == `true`] && 'Admin' || groups[?contains(@, '/grafana-edit') == `true`] && 'Editor' || 'Viewer'"

          allow_assign_grafana_admin = true
        }
        server = {
          root_url = "https://${local.fqdn}/"
        }
      }
      extraSecretMounts = [
        {
          name = "prometheus-grafana-cert"
          secretName = "prometheus-grafana-cert"
          mountPath = "/tls-secret"
        }
      ]
      ingress = {
        enabled = true
        annotations = {
          "cert-manager.io/cluster-issuer" = var.cert_issuer
        }
        ingressClassName = "private"
        hosts = [ local.fqdn ]
        tls = [
          {
            secretName = "prometheus-grafana-cert"
            hosts = [ local.fqdn ]
          }
        ]
      }
    }
  }
}

resource "helm_release" "release" {
  name  = var.release_name
  repository = var.helm_url
  chart = var.chart
  values = [yamlencode(local.config)]
  namespace = var.namespace

}

