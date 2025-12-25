#resource kubernetes_secret_v1 blueprint_groups_scope {
#  count = 0
#  metadata {
#    name = "group-scope-oauth2"
#    namespace = var.namespace
#  }
#  data = {
#    "groups_oath2.yaml" = templatefile("${path.module}/groups_scope.tfpl",{})
#  }
#}
