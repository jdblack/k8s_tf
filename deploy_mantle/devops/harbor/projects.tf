
variable projects { type = map }


resource harbor_project project {
  for_each = var.projects
  name = each.key
  force_destroy = true
  public = each.value.public
  auto_sbom_generation = true
}



