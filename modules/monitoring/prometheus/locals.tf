locals {
  helm_values = {
    grafana = {
      enabled = true
      # Velero fs-backup is opt-in per pod volume; `storage` is the grafana chart's volume name.
      podAnnotations = {
        "backup.velero.io/backup-volumes" = "storage"
      }
      "grafana.ini" = {
        server = {
          root_url = "https://${var.grafana_name}.${var.domain}/"
        }
        auth = {
          disable_login_form = true
        }
        "auth.generic_oauth" = {
          enabled              = true
          name                 = "Authentik"
          allow_sign_up        = true
          scopes               = "openid profile email groups"
          client_id            = "$__file{/etc/secrets/auth-generic-oauth/client_id}"
          client_secret        = "$__file{/etc/secrets/auth-generic-oauth/client_secret}"
          auth_url             = "https://auth.${var.domain}/application/o/authorize/"
          token_url            = "https://auth.${var.domain}/application/o/token/"
          api_url              = "https://auth.${var.domain}/application/o/userinfo/"
          signout_redirect_url = "https://auth.${var.domain}/application/o/${var.grafana_name}/end-session/"
          role_attribute_path  = "(contains(groups[*], '${var.grafana_name}-admin') || contains(groups[*], '${var.admin_group}')) && 'Admin' || 'Viewer'"
        }
        analytics = {
          check_for_updates        = false
          check_for_plugin_updates = false
        }
      }
      persistence = {
        enabled = true
        size    = "1Gi"
      }
      deploymentStrategy = {
        type = "Recreate"
      }
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

        # Every alert then carries the cluster that raised it.
        externalLabels = {
          cluster = var.domain
        }
      }
    }

    alertmanager = {
      alertmanagerSpec = {
        externalUrl = "https://${var.alertmanager_name}.${var.domain}"

        # The default OnNamespace scopes AlertmanagerConfig routes to alerts labelled
        # namespace=monitoring, which is almost none of them.
        alertmanagerConfigMatcherStrategy = {
          type = "None"
        }
      }
    }

    kubeEtcd              = { enabled = false }
    kubeScheduler         = { enabled = false }
    kubeControllerManager = { enabled = false }
    kubeProxy             = { enabled = false }

    defaultRules = {
      rules = {
        etcd                  = false
        kubeSchedulerAlerting = false
        kubeControllerManager = false
        kubeProxy             = false
      }
    }

    crds = {
      upgradeJob = {
        enabled = true
      }
    }
  }
}
