# The ingress half of the profile in `egress.tf`, and measured the same way. Outside peers that reach
# a pod here number two, and neither is a namespace of clients:
#   * the private gateway's data plane, for the three HTTPRoutes this namespace owns -- s3 :8333,
#     master :9333, and :9000 on the authentik outpost that fronts admin.seaweedfs.<domain>;
#   * Prometheus, on :9327.
# No CIDR peer on purpose: every Service here is ClusterIP, so the gateway is the only door a LAN or
# VPN client can come through -- and it is a door that a pod selector can name exactly.

# Namespace profile: `pod_selector` omitted on purpose. The guest list is identical for every role
# (master, filer, volume, s3, admin, worker, csi), so scoping this per pod would only mean writing the
# chart's labels down six times, and a seventh role would silently land outside the policy.
module "ingress_baseline" {
  source = "../network/firewalls/ingress"

  namespace = var.namespace
  name      = "kube-storage-baseline-ingress"

  from_peers = [
    # Gateway API data plane. Ports are the HTTPRoutes' backend ports, i.e. the target pod's own
    # (DNAT happens before policy): 9000 rather than the outpost's TLS 9443 -- the gateway terminates
    # TLS, so the jump to the outpost is plain HTTP. The master's gRPC 19333 is not in the list because
    # no route names it; only the chart's own pods speak it.
    {
      namespace    = var.gateway_namespace
      pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
      ports        = [{ port = 8333 }, { port = 9333 }, { port = 9000 }]
    },
    # ServiceMonitor scrape (`seaweedfs`, 275d old) against master, filer, volume, s3 and worker.
    # Whisker shows nothing for this one: Prometheus holds the connection open, and a connection that
    # never ends is never emitted -- so this guest was found in `up{namespace="kube-storage"}` (13
    # targets, all up), not in a flow. Reading the flow log alone denies the scrape on the next
    # reconnect, which is minutes later and looks like a dead exporter.
    {
      namespace    = var.monitoring_namespace
      pod_selector = { "app.kubernetes.io/name" = "prometheus" }
      ports        = [{ port = 9327 }]
    },
  ]
}
