# https://registry.terraform.io/providers/integrations/github/latest/docs/resources/branch_default

resource "github_branch" "branch_development" {
  repository = var.repository_name
  branch     = "development"
}

resource "github_branch" "branch_staging" {
  repository = var.repository_name
  branch     = "staging"
}

resource "github_branch_default" "default" {
  repository = var.repository_name
  branch     = "main"
}
