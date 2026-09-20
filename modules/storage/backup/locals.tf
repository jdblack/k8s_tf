locals {
  credentials = <<-EOT
    [default]
    aws_access_key_id=${random_password.access_key.result}
    aws_secret_access_key=${random_password.secret_key.result}
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
      backupStorageLocation = [{
        name     = "default"
        provider = "aws"
        bucket   = var.bucket
        default  = true
        config = {
          region           = var.region
          s3Url            = var.endpoint
          publicUrl        = var.public_endpoint
          s3ForcePathStyle = "true"
        }
      }]

      # Volume data stays opt-in: only annotated pods are captured.
      defaultVolumesToFsBackup = false
    }

    # Skipping the chart's default (invalid, providerless) VolumeSnapshotLocation; CSI
    # snapshots don't use VSLs and we're fs-backup-only.
    snapshotsEnabled = false

    deployNodeAgent = true
  }
}
