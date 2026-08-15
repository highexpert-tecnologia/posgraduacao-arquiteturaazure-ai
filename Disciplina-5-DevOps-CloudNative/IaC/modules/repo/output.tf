output "repository_name" {
  description = "The name of the created GitHub repository"
  value       = github_repository.repo.name
}

output "repository_id" {
  description = "The numeric GitHub repository ID used in GitHub Actions OIDC subjects"
  value       = github_repository.repo.repo_id
}
