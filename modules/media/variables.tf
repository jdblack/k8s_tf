variable namespace  { default = "media" }
variable movies_name { default = "movies" }
variable s3 { type = map }
variable cert_authorities  { type = map }
locals {
  region = var.s3["region"]
  bucket_root = var.s3["bucket_root"]
  bucket_url = "https://${local.bucket_root}.s3.${local.region}.amazonaws.com"
}

