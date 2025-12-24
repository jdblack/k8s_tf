locals {
  csi_s3_config = {
    "storageClass.mounter" = "s3fs"
    "storageClass.mountOptions" = "-o allow_other  -o umask=0222"
  }
}

resource helm_release csi_s3 {
  count = 0
  name = "csi-s3"
  namespace = var.namespace
  repository = "https://yandex-cloud.github.io/k8s-csi-s3/charts"
  version = "0.43.2"
  chart =  "csi-s3"
  set = [
    for key, value in local.csi_s3_config : {
      name  = key
      value = value
    }
  ]

}
