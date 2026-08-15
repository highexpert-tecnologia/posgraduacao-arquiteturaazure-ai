# https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository

resource "github_repository" "repo" {
  name        = var.name
  description = var.description
  visibility  = var.visibility

  allow_forking = false

  has_projects    = true
  has_wiki        = true
  has_issues      = true
  has_discussions = true

  topics = ["pos-graduacao", "devops"]
}

resource "github_repository_vulnerability_alerts" "repo" {
  repository = github_repository.repo.name
  enabled    = true
}
