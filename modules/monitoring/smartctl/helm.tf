
resource helm_release prometheus {
  name = var.name
  namespace = var.namespace
  repository = var.repo
  chart = var.chart

#  set  = [ 
#      name = "some.value"
#      value = "thing"
#    }
#  ]
#
#
#  set_list = [ 
#    {
#      name = "some.value"
#      value = [ "thing1", "thing2"]
#    }
#  ]
#

}

