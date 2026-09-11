# Grafana's OIDC client (generic_oauth) talks to authentik over TLS, and
# authentik's cert is signed by the private CA (var.cert_issuer) that
# cert_manager publishes as a ConfigMap in the `default` namespace. ConfigMap
# volumes can only be mounted from the pod's own namespace, so mirror it here;
# locals.tf points Grafana's Go TLS stack at it via SSL_CERT_FILE.
#
# Both resources live in the core stack (same config as cert_manager), so there
# is no cross-stack reference and nothing to flap against the mantle stack.
data "kubernetes_config_map_v1" "local_ca" {
  metadata {
    name = var.cert_issuer
  }
}

resource "kubernetes_config_map_v1" "grafana_ca" {
  metadata {
    name      = "${var.grafana_name}-ca"
    namespace = var.namespace
  }
  data = {
    "tls.crt" = data.kubernetes_config_map_v1.local_ca.data["tls.crt"]
  }
}

# Placeholder Grafana OIDC secret.
#
# Grafana's $__file{} expander HARD-FAILS when the referenced file is MISSING
# (verified against grafana 13.2.1-distroless: the container exits with "got
# error while expanding auth.generic_oauth.client_id ... no such file"), but
# boots fine when the file exists and only holds a placeholder. So core has to
# guarantee the Secret OBJECT exists before its helm upgrade waits on the
# Grafana pod -- otherwise a from-scratch build times out: helm waits 5 minutes
# for a pod that can never mount the volume, because the real secret is minted
# by the mantle stack and core runs first.
#
# Ownership: core owns the object, the mantle stack owns the DATA (it writes
# the real client credentials with kubernetes_secret_v1_data). ignore_changes on
# `data` is what stops the two stacks flapping -- without it every core apply
# would see mantle's real credentials sitting in the object, call it drift, and
# blank them back to the placeholder.
resource "random_uuid" "grafana_oidc_client_id" {}

resource "random_password" "grafana_oidc_client_secret" {
  length  = 40
  special = false
}

resource "kubernetes_secret_v1" "grafana_oidc" {
  metadata {
    name      = "${var.grafana_name}-oidc"
    namespace = var.namespace
  }
  data = {
    client_id     = random_uuid.grafana_oidc_client_id.result
    client_secret = random_password.grafana_oidc_client_secret.result
  }

  lifecycle {
    # `data` is the whole point: mantle owns the real credentials via
    # kubernetes_secret_v1_data, so core must never plan a diff on it.
    #
    # `wait_for_service_account_token` is the k8s provider 3.x default (true);
    # the imported object predates it. Ignoring it keeps core from planning ANY
    # in-place update -- which matters, because an update would make the
    # provider re-send `data` from core's (now stale) state copy and stomp on
    # whatever mantle last wrote.
    ignore_changes = [data, wait_for_service_account_token]
  }
}
