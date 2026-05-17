# ── Networking ──
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (for ElastiCache)"
  value       = aws_subnet.private[*].id
}

output "isolated_subnet_ids" {
  description = "Isolated subnet IDs (for RDS)"
  value       = aws_subnet.isolated[*].id
}

# ── ElastiCache ──
output "elasticache_endpoint" {
  description = "ElastiCache Redis endpoint — BFF reads this from SSM at runtime"
  value       = var.is_local ? "localhost:6379" : aws_elasticache_replication_group.prod[0].primary_endpoint_address
}

output "elasticache_port" {
  description = "ElastiCache Redis port"
  value       = 6379
}

# ── RDS ──
output "rds_endpoint" {
  description = "RDS Aurora PostgreSQL endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

# ── S3 ──
output "s3_assets_bucket" {
  description = "S3 assets bucket name"
  value       = aws_s3_bucket.assets.bucket
}

output "s3_uploads_bucket" {
  description = "S3 uploads bucket name"
  value       = aws_s3_bucket.uploads.bucket
}

output "s3_exports_bucket" {
  description = "S3 exports bucket name"
  value       = aws_s3_bucket.exports.bucket
}

# ── SQS ──
output "sqs_notifications_url" {
  description = "SQS notifications queue URL"
  value       = aws_sqs_queue.notifications.url
}

output "sqs_notifications_arn" {
  description = "SQS notifications queue ARN"
  value       = aws_sqs_queue.notifications.arn
}

output "sqs_dlq_url" {
  description = "SQS dead-letter queue URL"
  value       = aws_sqs_queue.dlq.url
}

# ── SNS ──
output "sns_events_arn" {
  description = "SNS events topic ARN"
  value       = aws_sns_topic.events.arn
}

# ── Secrets ──
output "secrets_db_creds_arn" {
  description = "Secrets Manager DB credentials ARN"
  value       = aws_secretsmanager_secret.db_creds.arn
}

output "secrets_jwt_secret_arn" {
  description = "Secrets Manager JWT secret ARN"
  value       = aws_secretsmanager_secret.jwt_secret.arn
}

# ── SSM Parameter Paths ──
output "ssm_parameter_paths" {
  description = "SSM Parameter Store paths the BFF should read at runtime"
  value = {
    elasticache_endpoint = aws_ssm_parameter.elasticache_endpoint.name
    rds_endpoint         = aws_ssm_parameter.rds_endpoint.name
    s3_assets_bucket     = aws_ssm_parameter.s3_assets_bucket.name
    sqs_notifications    = aws_ssm_parameter.sqs_notifications_url.name
    environment          = aws_ssm_parameter.environment.name
    bff_port             = aws_ssm_parameter.bff_port.name
  }
}

# ── IAM ──
output "bff_task_role_arn" {
  description = "IAM role ARN for the BFF ECS task"
  value       = aws_iam_role.bff_task.arn
}
