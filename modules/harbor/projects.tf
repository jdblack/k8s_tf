
module harbor_projects {
  source = "./project"
  projects = var.projects
  providers = {
    harbor = harbor
  }
}

