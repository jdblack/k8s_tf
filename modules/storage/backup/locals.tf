locals {
  credentials = <<-EOT
    [default]
    aws_access_key_id=${random_password.access_key.result}
    aws_secret_access_key=${random_password.secret_key.result}
  EOT

  offsite_credentials = <<-EOT
    [default]
    aws_access_key_id=${var.offsite_access_key}
    aws_secret_access_key=${var.offsite_secret_key}
  EOT

  helm_values = {
    initContainers = [{
      name         = "velero-plugin-for-aws"
      image        = var.aws_plugin_image
      volumeMounts = [{ name = "plugins", mountPath = "/target" }]
    }]

    credentials = {
      useSecret      = true
      existingSecret = kubernetes_secret_v1.credentials.metadata[0].name
    }

    configuration = {
      backupStorageLocation = [
        {
          name     = "default"
          provider = "aws"
          bucket   = var.bucket
          default  = true
          config = {
            region           = var.region
            s3Url            = var.endpoint
            s3ForcePathStyle = "true"
          }
        },
        {
          name     = "backblaze"
          provider = "aws"
          bucket   = var.offsite_bucket
          credential = {
            name = kubernetes_secret_v1.offsite_credentials.metadata[0].name
            key  = "cloud"
          }
          config = {
            region           = var.offsite_region
            s3Url            = var.offsite_endpoint
            s3ForcePathStyle = "true"
            # B2 rejects the SDK's default checksum headers (XAmzContentSHA256Mismatch).
            checksumAlgorithm = ""
          }
        },
      ]

      # Volume data stays opt-in: only annotated pods are captured.
      defaultVolumesToFsBackup = false
    }

    # Skipping the chart's default (invalid, providerless) VolumeSnapshotLocation; CSI
    # snapshots don't use VSLs and we're fs-backup-only.
    snapshotsEnabled = false

    deployNodeAgent = true
  }
}
