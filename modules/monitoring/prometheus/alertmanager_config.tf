locals {
  pushover_enabled = var.pushover_user_key != "" && var.pushover_token != ""

  # Nothing configured means nothing to route to: stay with the chart's null receiver.
  notify_enabled = local.pushover_enabled || var.slack_webhook_routine != ""

  notify_secret = "alertmanager-notify"

  alertmanager_url = "https://${var.alertmanager_name}.${var.domain}/#/alerts"

  notify_title = "{{ if eq .Status \"firing\" }}[{{ .CommonLabels.severity }}]{{ else }}[resolved]{{ end }} {{ .CommonLabels.alertname }}"

  # Pushover caps a message at 1024 characters, so this stays short on purpose.
  notify_body = <<-EOT
    {{ .CommonAnnotations.summary }}{{ if .CommonAnnotations.description }}
    {{ .CommonAnnotations.description }}{{ end }}{{ if gt (len .Alerts) 1 }}
    {{ len .Alerts }} alerts{{ end }}
  EOT

  # Emergency alerts are a subset of the phone list; routing them separately is what
  # keeps them from being sent twice.
  phone_only_pattern = join("|", setsubtract(var.phone_alerts, var.emergency_alerts))

  pushover_config = {
    sendResolved = true
    userKey      = { name = local.notify_secret, key = "pushover-user-key" }
    token        = { name = local.notify_secret, key = "pushover-token" }
    title        = local.notify_title
    message      = local.notify_body
    url          = local.alertmanager_url
    urlTitle     = "Alertmanager"
  }

  slack_config = {
    sendResolved = true
    title        = local.notify_title
    titleLink    = local.alertmanager_url
    text         = local.notify_body
    color        = "{{ if eq .Status \"firing\" }}danger{{ else }}good{{ end }}"
    username     = "Alertmanager"
    iconEmoji    = ":rotating_light:"
  }

  # Pushover and Slack receivers carry different fields, and Terraform refuses to
  # unify object types within one list, so each is JSON-encoded until assembled.
  #
  # "silent" is an empty receiver: the CRD rejects a route pointing at a receiver
  # the CR doesn't define, so the chart's own "null" is not usable here.
  receivers_json = compact([
    jsonencode({ name = "silent" }),
    local.pushover_enabled ? jsonencode({
      name            = "pushover-phone"
      pushoverConfigs = [merge(local.pushover_config, { priority = "1" })]
    }) : "",
    local.pushover_enabled ? jsonencode({
      name = "pushover-emergency"
      pushoverConfigs = [merge(local.pushover_config, {
        priority = "2"
        retry    = "5m"
        expire   = "3h"
      })]
    }) : "",
    var.slack_webhook_routine != "" ? jsonencode({
      name         = "slack-routine"
      slackConfigs = [merge(local.slack_config, { apiURL = { name = local.notify_secret, key = "slack-webhook-routine" } })]
    }) : "",
    var.slack_webhook_mirror != "" ? jsonencode({
      name         = "slack-mirror"
      slackConfigs = [merge(local.slack_config, { apiURL = { name = local.notify_secret, key = "slack-webhook-mirror" } })]
    }) : "",
  ])

  receivers = [for encoded in local.receivers_json : jsondecode(encoded)]

  # Order is the policy: muted stops, the mirror continues into the phone routes.
  routes = concat(
    [{
      receiver = "silent"
      continue = false
      matchers = [{ name = "alertname", matchType = "=~", value = join("|", var.muted_alerts) }]
    }],
    var.slack_webhook_mirror != "" && local.pushover_enabled ? [{
      receiver = "slack-mirror"
      continue = true
      matchers = [{ name = "alertname", matchType = "=~", value = join("|", var.phone_alerts) }]
    }] : [],
    local.pushover_enabled ? [
      {
        receiver = "pushover-emergency"
        continue = false
        matchers = [{ name = "alertname", matchType = "=~", value = join("|", var.emergency_alerts) }]
      },
      {
        receiver = "pushover-phone"
        continue = false
        matchers = [{ name = "alertname", matchType = "=~", value = local.phone_only_pattern }]
      },
    ] : [],
  )
}

resource "kubernetes_secret_v1" "notify" {
  count = local.notify_enabled ? 1 : 0

  metadata {
    name      = local.notify_secret
    namespace = var.namespace
  }

  data = merge(
    local.pushover_enabled ? {
      pushover-user-key = var.pushover_user_key
      pushover-token    = var.pushover_token
    } : {},
    var.slack_webhook_routine != "" ? { slack-webhook-routine = var.slack_webhook_routine } : {},
    var.slack_webhook_mirror != "" ? { slack-webhook-mirror = var.slack_webhook_mirror } : {},
  )
}

resource "kubectl_manifest" "alertmanager_config" {
  count = local.notify_enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1alpha1"
    kind       = "AlertmanagerConfig"

    metadata = {
      name      = "notifications"
      namespace = var.namespace

      # The operator's fallback matcher, so the CR is found even with the selectors unset.
      labels = { alertmanager = "prometheus-kube-prometheus-alertmanager" }
    }

    spec = {
      route = {
        # Slack is the routine channel; without it, unmatched alerts stay silent
        # rather than failing the CRD's "receiver must be defined here" check.
        receiver = var.slack_webhook_routine != "" ? "slack-routine" : "silent"

        groupBy        = ["alertname", "namespace", "node"]
        groupWait      = "30s"
        groupInterval  = "5m"
        repeatInterval = "12h"

        routes = local.routes
      }

      receivers = local.receivers

      # A node going down also breaks everything that ran on it.
      inhibitRules = [{
        equal       = ["node"]
        sourceMatch = [{ name = "alertname", matchType = "=~", value = "KubeNodeNotReady|KubeNodeUnreachable|KubeNodePressure" }]
        targetMatch = [{ name = "severity", matchType = "=~", value = "info|warning" }]
      }]
    }
  })

  depends_on = [kubernetes_secret_v1.notify]
}
