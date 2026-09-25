variable "prometheus_name" { default = "prometheus" }

variable "namespace" { type = string }
variable "cert_issuer" { type = string }
variable "domain" { type = string }
variable "grafana_name" { default = "grafana" }

variable "helm_version" { default = "91.4.1" }

variable "admin_group" {
  type    = string
  default = "authentik Admins"
}

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }

variable "alertmanager_name" { default = "alertmanager" }

# Empty disables Pushover: everything then stays on the Slack route.
variable "pushover_user_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "pushover_token" {
  type      = string
  sensitive = true
  default   = ""
}

# Routine traffic. Empty leaves the base route on "null", which alerts nothing.
variable "slack_webhook_routine" {
  type      = string
  sensitive = true
  default   = ""
}

# Second webhook: a Slack copy of everything that reached a phone.
variable "slack_webhook_mirror" {
  type      = string
  sensitive = true
  default   = ""
}

# The only alertnames allowed to reach a phone. Every name here is defined by the
# module that owns the metric, so a rule rename lands in two places on purpose.
variable "phone_alerts" {
  type = list(string)
  default = [
    "AlertmanagerClusterDown",
    "CertManagerCertificateExpiringCritical",
    "KubeNodeNotReady",
    "KubeNodePressure",
    "KubeNodeUnreachable",
    "KubePersistentVolumeErrors",
    "KubePersistentVolumeFillingUp",
    "KubePersistentVolumeInodesFillingUp",
    "KubeletDown",
    "LonghornVolumeDegraded",
    "LonghornVolumeFaulted",
    "NodeFilesystemAlmostOutOfSpace",
    "NodeFilesystemFilesFillingUp",
    "NodeFilesystemSpaceFillingUp",
    "NodeRAIDDegraded",
    "NodeRAIDDiskFailure",
    "SeaweedFSNoMasterLeader",
    "SeaweedFSVolumeDiskError",
    "SmartDeviceCriticalWarning",
    "SmartDeviceHealthFailing",
    "SmartDeviceMediaErrors",
    "VeleroBackupFailures",
    "VeleroBackupStale",
  ]
}

# Pushover priority 2: nags until acknowledged.
variable "emergency_alerts" {
  type = list(string)
  default = [
    "LonghornVolumeFaulted",
    "SmartDeviceHealthFailing",
    "SmartDeviceMediaErrors",
  ]
}

# Noisy kube-prometheus-stack defaults, dropped before they train anyone to ignore notifications.
variable "muted_alerts" {
  type = list(string)
  default = [
    "CPUThrottlingHigh",
    "InfoInhibitor",
    "KubeCPUOvercommit",
    "KubeCPUQuotaOvercommit",
    "KubeClientCertificateExpiration",
    "KubeHpaMaxedOut",
    "KubeMemoryOvercommit",
    "KubeMemoryQuotaOvercommit",
    "KubeVersionMismatch",
    "KubeletClientCertificateExpiration",
    "KubeletTooManyPods",
    "NodeCPUHighUsage",
    "NodeClockNotSynchronising",
    "NodeClockSkewDetected",
    "NodeDiskIOSaturation",
    "NodeHighNumberConntrackEntriesUsed",
    "NodeMemoryHighUtilization",
    "NodeNetworkInterfaceFlapping",
    "NodeSystemSaturation",
    "Watchdog",
  ]
}
