module media {
  source = "../modules/media"
  namespace = "media"
  media_s3_auth = var.media.movies
  domain = var.deployment.common.domain
  cert_issuer = var.deployment.cert.pub_cert_issuer

}
