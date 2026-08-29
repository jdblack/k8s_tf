
module fuckbatz_website {
  source = "git::https://github.com/Linuxgurus/wordpress.git//terraform?ref=main"
  name = "fuckbatz-website"
  namespace = "fuckbatz"
  hostname = "www.notbatz.com"
  cert_issuer = "letsencrypt-http"
  ingress_class = "public"
  extra_hostnames = [ "notbatz.com" ]
}
