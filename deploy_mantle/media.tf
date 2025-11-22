module media {
  source = "../modules/media"
  namespace = "media"
  s3 = var.juice.s3
  cert_authorities = var.deployment.cert_authorities
}
