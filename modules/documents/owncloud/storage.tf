# The decomposedfs metadata is xattr-heavy, which is why it lands on longhorn's ext4 rather
# than a FUSE-backed class. Almost nothing stored here is actually metadata though: s3ng
# stages each whole upload before shipping the blob out, so the claim is sized by the
# uploads in flight at once, not by the tree it describes. See metadata_size.
resource "kubernetes_persistent_volume_claim_v1" "metadata" {
  metadata {
    name      = "owncloud-metadata"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = var.metadata_size
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "storagesystem" {
  metadata {
    name      = "owncloud-storagesystem"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = var.storagesystem_size
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "nats" {
  metadata {
    name      = "owncloud-nats"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = var.nats_size
      }
    }
  }
}

# Owner matters as much as the bucket: an S3 identity only reaches buckets it owns, and
# `s3.bucket.create` rewrites the entry, so the owner is set after the create.
module "bucket" {
  source = "../../storage/seaweedfs/bucket"

  bucket = var.s3_bucket
  owner  = var.name
}

module "s3_user" {
  source = "../../storage/seaweedfs/s3_user"

  user      = var.name
  bucket    = module.bucket.bucket
  role      = "admin"
  namespace = var.namespace
}
