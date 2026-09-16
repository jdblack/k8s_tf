locals {
  helm_values = {
    grafana = {
      enabled = true
      "grafana.ini" = {
        # root_url builds the OAuth redirect_uri, which authentik matches strictly.
        server = {
          root_url = "https://${var.grafana_name}.${var.domain}/"
        }
        # Form off, basic auth on: the chart's dashboard sidecars use the latter.
        auth = {
          disable_login_form = true
        }
        "auth.generic_oauth" = {
          enabled       = true
          name          = "Authentik"
          allow_sign_up = true
          scopes        = "openid profile email groups"
          # Written by the mantle stack; $__file{} resolves at startup only.
          client_id            = "$__file{/etc/secrets/auth-generic-oauth/client_id}"
          client_secret        = "$__file{/etc/secrets/auth-generic-oauth/client_secret}"
          auth_url             = "https://auth.${var.domain}/application/o/authorize/"
          token_url            = "https://auth.${var.domain}/application/o/token/"
          api_url              = "https://auth.${var.domain}/application/o/userinfo/"
          signout_redirect_url = "https://auth.${var.domain}/application/o/${var.grafana_name}/end-session/"
          # <name>-admin or the superuser group => Admin, else Viewer. The parens are
          # load-bearing: JMESPath binds && tighter than ||.
          role_attribute_path = "(contains(groups[*], '${var.grafana_name}-admin') || contains(groups[*], '${var.admin_group}')) && 'Admin' || 'Viewer'"
        }
        # grafana.com polls, every ten minutes: the version banner and the installed-plugin
        # list. Both are UI-only and the namespace's only outbound traffic, and monitoring's
        # egress is being closed (pod_cidr + node IPs only), so turn them off rather than let
        # them fail against the firewall.
        analytics = {
          check_for_updates        = false
          check_for_plugin_updates = false
        }
      }
      persistence = {
        enabled = true
        size    = "1Gi"
      }
      # RWO volume: RollingUpdate deadlocks, so terminate first.
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
      }
    }

    # OFF: kubeadm binds these to loopback while Prometheus scrapes the node IP, so
    # every target is a permanent connection-refused. The matching defaultRules are
    # `absent(up{...})` and would fire as soon as the targets vanish.
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

    # Helm only creates a chart's crds/ when absent; this hook server-side-applies
    # them, which is the only thing keeping them in step with chart bumps.
    crds = {
      upgradeJob = {
        enabled = true
      }
    }
  }
}
