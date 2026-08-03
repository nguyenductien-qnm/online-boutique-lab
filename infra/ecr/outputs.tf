output "repository_names" {
  description = "ECR repository names keyed by service."
  value = {
    for service, repository in aws_ecr_repository.service : service => repository.name
  }
}

output "repository_urls" {
  description = "ECR repository URLs keyed by service."
  value = {
    for service, repository in aws_ecr_repository.service : service => repository.repository_url
  }
}

output "registry_id" {
  description = "AWS account registry ID hosting the repositories."
  value       = values(aws_ecr_repository.service)[0].registry_id
}
