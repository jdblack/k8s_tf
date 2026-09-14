locals {
  # Grafana + Prometheus values.
  helm_values = {
    grafana = {
      enabled = true
      "grafana.ini" = {
        # Grafana builds the OAuth redirect_uri from root_url; authentik
        # matches it strictly.
        server = {
          root_url = "https://${var.grafana_name}.${var.domain}/"
        }
        # SSO-only login form. Basic auth stays ON: the chart's dashboard
        # sidecars use it to call the provisioning-reload API.
        auth = {
          disable_login_form = true
        }
        "auth.generic_oauth" = {
          enabled       = true
          name          = "Authentik"
          allow_sign_up = true
          scopes        = "openid profile email groups"
          # Credentials are written by the mantle stack (authentik
          # oidc_provider); $__file{} resolves at startup only.
          client_id            = "$__file{/etc/secrets/auth-generic-oauth/client_id}"
          client_secret        = "$__file{/etc/secrets/auth-generic-oauth/client_secret}"
          auth_url             = "https://auth.${var.domain}/application/o/authorize/"
          token_url            = "https://auth.${var.domain}/application/o/token/"
          api_url              = "https://auth.${var.domain}/application/o/userinfo/"
          signout_redirect_url = "https://auth.${var.domain}/application/o/${var.grafana_name}/end-session/"
          # `<name>-admin` (or the superuser group) => Admin, else Viewer.
          # The parentheses are load-bearing: JMESPath binds && tighter than
          # ||, and Grafana rejects a non-role result.
          role_attribute_path = "(contains(groups[*], '${var.grafana_name}-admin') || contains(groups[*], '${var.admin_group}')) && 'Admin' || 'Viewer'"
        }
      }
      persistence = {
        enabled = true
        size    = "1Gi"
      }
      # RWO volume: RollingUpdate deadlocks (the new pod can't attach while the
      # old one holds it), so terminate first.
      deploymentStrategy = {
        type = "Recreate"
      }
      # Trust the private CA that signs authentik's TLS cert (Go reads
      # SSL_CERT_FILE alongside the system roots).
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

    # Control-plane scrapers are OFF. kubeadm binds scheduler (:10259),
    # controller-manager (:10257), etcd (:2381) and kube-proxy (:10249) to
    # loopback while Prometheus scrapes the node IP, so every target is a permanent
    # connection-refused that fires alarming nonsense (etcd "quorum loss" on a
    # healthy cluster). The matching defaultRules groups must go with them: they
    # are `absent(up{job=...})` and fire the moment the targets vanish. etcd metrics
    # would be worth having -- enabling them is a kubeadm extraArgs/patches change,
    # not a chart one.
    kubeEtcd              = { enabled = false }
    kubeScheduler         = { enabled = false }
    kubeControllerManager = { enabled = false }
    kubeProxy             = { enabled = false }

    # Only the four groups above are overridden; helm deep-merges the rest.
    defaultRules = {
      rules = {
        etcd                  = false
        kubeSchedulerAlerting = false
        kubeControllerManager = false
        kubeProxy             = false
      }
    }

    # Helm never upgrades CRDs from a chart's crds/ dir -- it only creates them when
    # absent -- so these had frozen at operator v0.84.1 while the release rode chart
    # 82 -> 90 (operator v0.93.1). This pre-install/pre-upgrade hook
    # server-side-applies them with --force-conflicts and is the only thing that
    # keeps them in lockstep with future bumps.
    crds = {
      upgradeJob = {
        enabled = true
      }
    }
  }
}
