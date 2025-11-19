module movies {
  name = var.movies_name
  source = "../storage/juicefs/static_volume/"
  namespace = var.namespace
  bucket_url = local.bucket_url
  access_key = var.s3["access_key"]
  secret_key = var.s3["secret_key"]
}
