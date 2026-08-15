#https://registry.terraform.io/providers/integrations/github/latest/docs/resources/issue_label.html

resource "github_issue_labels" "labels" {
  repository = var.repository_name

  label {
    name        = "dependabot"
    description = "Dependabot alerts and PRs"
    color       = "FF0000"
  }

  label {
    name        = "urgent"
    description = "Requires immediate attention"
    color       = "FF0000"
  }

  label {
    name        = "critical"
    description = "Critical issue that needs to be resolved as soon as possible"
    color       = "FF0000"
  }

  label {
    name        = "documentation"
    description = "Issues related to documentation improvements or updates"
    color       = "0000FF"
  }

  label {
    name        = "enhancement"
    description = "Issues related to new features or improvements to existing functionality"
    color       = "00FF00"
  }

  label {
    name        = "new-feature"
    description = "Issues related to the development of new features or functionality"
    color       = "00FF00"
  }

  label {
    name        = "bug"
    description = "Issues related to bugs or errors in the code"
    color       = "FFFF00"
  }

  label {
    name        = "duplicate"
    description = "Issues that are duplicates of other issues"
    color       = "FF00FF"
  }

  label {
    name        = "invalid"
    description = "Issues that are not valid or cannot be reproduced"
    color       = "00FFFF"
  }

  label {
    name        = "wontfix"
    description = "Issues that will not be fixed or addressed"
    color       = "C0C0C0"
  }

}
