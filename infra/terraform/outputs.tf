output "app_url" {
  description = "Public URL for the deployed order satellite service."
  value       = "http://${aws_lb.app.dns_name}"
}

output "ecr_repository_url" {
  description = "ECR repository URL used by the deployment workflow."
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.app.name
}

output "ecs_service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.app.name
}

output "log_group_name" {
  description = "CloudWatch Logs group for the ECS task."
  value       = aws_cloudwatch_log_group.app.name
}
