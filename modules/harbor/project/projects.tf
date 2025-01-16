
variable projects { type = map }


resource harbor_project project {
  for_each = var.projects
  name = each.key
  public = each.value.public
  depends_on = [null_resource.wait_before_create]  # Make the module dependent on the wait

}

resource "null_resource" "wait_before_create" {
  provisioner "local-exec" {
    command = "sleep 60"  # Wait for 60 seconds
  }
}



