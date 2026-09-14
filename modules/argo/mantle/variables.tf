variable "namespace" {}
variable "deploy_key" {}
variable "repo" {}

variable "oauth2_server" {}
variable "domain" {}

# Listener-only now: passed down to argo-workflows for the argo-wf.vn
# ListenerSet. argo-cd's own listener is declared in modules/argo/core, and no
# module under here injects a CA any more.
variable "cert_issuer" {}


