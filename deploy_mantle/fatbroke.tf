resource kubernetes_namespace fatbroke_ns {
  metadata {
    name = "notbatz-com"
  }
}
module fatbroke_volume  {
  source = "../modules/storage/juicefs/static_volume/"
  namespace = kubernetes_namespace.fatbroke_ns.id
  name = "notbatz-com"
  bucket_url = var.media.fatandbroke.url
  access_key =  var.media.fatandbroke.access_key_id
  secret_key =  var.media.fatandbroke.secret_access_key
}

