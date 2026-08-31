locals {
  sso_secret = "${var.name}-sso-creds"
  fqdn       = "${var.name}.${var.domain}"
  config = {
    server = {
      volumes = [
        {
          name = "ca-certs"
          hostPath = {
            path = "/etc/ssl/certs/ca-certificates.crt"
          }
        }
      ],
      volumeMounts = [
        {
          name      = "ca-certs"
          mountPath = "/etc/ssl/certs/ca-certificates.crt"
        }
      ]
      service = {
        type = "ClusterIP"
      }
      authModes = ["sso"]
      sso = {
        enabled = true,
        issuer  = "https://${var.sso_server}/application/o/${var.name}/",
        scopes  = ["openid", "profile", "email", "groups"],
        clientId = {
          key  = "client_id"
          name = local.sso_secret
        }
        clientSecret = {
          key  = "secret"
          name = local.sso_secret
        }
      }
    }
  }
}
