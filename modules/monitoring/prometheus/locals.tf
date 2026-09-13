locals {
  # Grafana + Prometheus values.
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

    # The control plane is deliberately NOT scraped. kubeadm binds these four
    # sets of metrics to loopback, so each target is a permanent
    # connection-refused, not an intermittent failure:
    #
    #   kube-scheduler          --bind-address=127.0.0.1                 :10259
    #   kube-controller-manager --bind-address=127.0.0.1                 :10257
    #   etcd                    --listen-metrics-urls=http://127.0.0.1:2381
    #   kube-proxy              metricsBindAddress unset -> default
    #                           127.0.0.1:10249, on every node
    #
    # The first three are kubeadm's hardcoded defaults (controlplane/manifests.go
    # `defaultArguments`); kube-proxy's loopback default has held since at least
    # k8s 1.27. Prometheus scrapes the node IP, so it can never connect. Nothing
    # is broken -- the cluster is healthy -- but the alerts this produces are
    # pure noise, and etcdInsufficientMembers phrases it as a CRITICAL quorum
    # loss, a false alarm that devalues the ones that are real. Exposing the
    # metrics instead is a kubeadm/node-side change (and a LAN-exposure
    # decision), not something this chart can do.
    #
    # Disabling the SCRAPERS is what actually clears it. TargetDown lives in the
    # `general` rules group alongside Watchdog, and rule groups cannot be
    # partially disabled, so silencing rules cannot cover it -- only removing
    # the targets can.
    #
    # The matching rule groups MUST go too: KubeSchedulerDown / KubeProxyDown /
    # KubeControllerManagerDown are `absent(up{job=...})`, so the instant the
    # targets vanish they fire in place of the *InstanceUnreachable alerts and
    # we would trade one alert for another. Both levers, always.
    #
    # etcd is the one component whose metrics are worth having -- the capacity
    # warnings (quota, fsync, DB growth) give real lead time, whereas the
    # availability ones are redundant on a single-member control plane. If it is
    # ever switched on, do it via kubeadm extraArgs/patches so it survives
    # `kubeadm upgrade`, and re-enable defaultRules.rules.etcd with it.
    kubeEtcd              = { enabled = false }
    kubeScheduler         = { enabled = false }
    kubeControllerManager = { enabled = false }
    kubeProxy             = { enabled = false }

    # Only the four groups named above are overridden; helm deep-merges these
    # onto the chart defaults, so `general` (TargetDown/Watchdog), `kubernetesApps`,
    # `node`, etc. all stay enabled.
    defaultRules = {
      rules = {
        etcd                  = false
        kubeSchedulerAlerting = false
        kubeControllerManager = false
        kubeProxy             = false
      }
    }

    # The `.monitoring.coreos.com` CRDs had fallen nine operator releases behind
    # the operator that serves them.
    #
    # Helm NEVER upgrades or deletes CRDs that live in a chart's `crds/`
    # directory -- it only creates them when they are absent. So these 10 CRDs
    # were frozen at operator v0.84.1 while this release rode chart 82 -> 88 ->
    # 90 (operator v0.93.1): a new operator speaking a schema its own CRDs did
    # not define. Nothing in Terraform could see it, because `helm upgrade`
    # never looks.
    #
    # Backfilled by hand on 2026-09-13 after verifying the change was safe: no
    # served version dropped (all nine v1 + one v1alpha1 intact), and zero
    # removed schema paths at ANY depth across all 10 CRDs -- purely additive,
    # so nothing could be pruned off the 35 PrometheusRules / 17
    # ServiceMonitors / 1 Prometheus / 1 Alertmanager in use. All 10 now report
    # operator.prometheus.io/version: 0.93.1.
    #
    # This job is the chart's own answer to the problem: a pre-install /
    # pre-upgrade helm hook that server-side-applies the bundled CRDs with
    # --force-conflicts (taking field ownership from whoever installed them)
    # before the operator rolls. It is what makes the fix stick -- without it,
    # every future chart bump silently re-creates the same mismatch. Upstream
    # labels it preview; it is also the only mechanism that keeps the CRDs in
    # lockstep with the release. `forceConflicts` already defaults to true.
    crds = {
      upgradeJob = {
        enabled = true
      }
    }
  }
}
