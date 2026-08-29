
module ngoc_website {
  source = "git::https://github.com/Linuxgurus/wordpress.git//terraform?ref=main"
  name = "ngoc-website"
  namespace = "ngoc"
  hostname = "www.emtho.com"
  cert_issuer = "letsencrypt-http"
  ingress_class = "public"
  extra_hostnames = [ "emtho.com" ]
}
