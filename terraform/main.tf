# ── Data Sources ──
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" { state = "available" }

# ── Locals ──
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# ═══════════════════════════════════════════
# VPC & Networking
# ═══════════════════════════════════════════

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-vpc" })
}

resource "aws_subnet" "public" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-${var.availability_zones[count.index]}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + length(var.availability_zones))
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-${var.availability_zones[count.index]}"
    Tier = "private"
  })
}

resource "aws_subnet" "isolated" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + (length(var.availability_zones) * 2))
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-isolated-${var.availability_zones[count.index]}"
    Tier = "isolated"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-igw" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-public-rt" })
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ── Security Groups ──

resource "aws_security_group" "bff" {
  name_prefix = "${local.name_prefix}-bff-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "BFF HTTP from ALB / local dev"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-bff-sg" })
}

resource "aws_security_group" "cache" {
  name_prefix = "${local.name_prefix}-cache-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.bff.id]
    description     = "Redis from BFF only"
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-cache-sg" })
}

resource "aws_security_group" "database" {
  name_prefix = "${local.name_prefix}-db-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.bff.id]
    description     = "PostgreSQL from BFF only"
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-db-sg" })
}

# ═══════════════════════════════════════════
# ElastiCache (Redis)
# ═══════════════════════════════════════════
#
# Dev: MiniStack soporta ElastiCache API (create/describe) pero el provider
# de Terraform crashea al leer la respuesta (nil pointer en campos como
# CacheNodeCreateTime, y DescribeCacheClusters devuelve 404 para los
# nodos del replication group). Por eso en dev usamos localhost:6379
# directamente — MiniStack expone Redis en ese puerto.
#
# Prod: ElastiCache real con replication group multi-AZ.
#
# El BFF siempre lee el endpoint de SSM Parameter Store — mismo código,
# mismo flujo, sin importar el entorno.

resource "aws_elasticache_subnet_group" "main" {
  count = var.is_local ? 0 : 1

  name       = "${local.name_prefix}-cache-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = local.common_tags
}

resource "aws_elasticache_replication_group" "prod" {
  count = var.is_local ? 0 : 1

  replication_group_id = "${local.name_prefix}-redis"
  description          = "TaskFlow Redis cache"

  engine            = "redis"
  engine_version    = "7.0"
  node_type         = var.cache_node_type
  port              = 6379
  multi_az_enabled  = var.cache_num_nodes > 1

  num_node_groups         = 1
  replicas_per_node_group = var.cache_num_nodes - 1

  subnet_group_name  = aws_elasticache_subnet_group.main[0].name
  security_group_ids = [aws_security_group.cache.id]

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-redis" })
}

# ═══════════════════════════════════════════
# RDS Aurora PostgreSQL
# ═══════════════════════════════════════════

resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = aws_subnet.isolated[*].id

  tags = local.common_tags
}

resource "aws_db_instance" "main" {
  identifier     = "${local.name_prefix}-db"
  engine         = "postgres"
  engine_version = "16"
  instance_class = var.db_instance_class

  allocated_storage = 20
  max_allocated_storage = var.is_local ? null : 100  # Storage autoscaling (prod only)

  db_name  = "taskflow"
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.database.id]

  multi_az           = !var.is_local
  storage_encrypted  = !var.is_local
  publicly_accessible = false

  skip_final_snapshot = var.is_local
  final_snapshot_identifier = var.is_local ? null : "${local.name_prefix}-db-final-snapshot"

  backup_retention_period = var.is_local ? 0 : 7
  deletion_protection     = var.is_local ? false : true

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-db" })
}

# ═══════════════════════════════════════════
# S3 Buckets
# ═══════════════════════════════════════════

resource "aws_s3_bucket" "assets" {
  bucket = "${local.name_prefix}-assets"

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-assets" })
}

resource "aws_s3_bucket" "uploads" {
  bucket = "${local.name_prefix}-uploads"

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-uploads" })
}

resource "aws_s3_bucket" "exports" {
  bucket = "${local.name_prefix}-exports"

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-exports" })
}

resource "aws_s3_bucket_versioning" "assets" {
  count  = var.is_local ? 0 : 1
  bucket = aws_s3_bucket.assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "all" {
  for_each = {
    assets  = aws_s3_bucket.assets.id
    uploads = aws_s3_bucket.uploads.id
    exports = aws_s3_bucket.exports.id
  }

  bucket = each.value

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ═══════════════════════════════════════════
# SQS Queues
# ═══════════════════════════════════════════

resource "aws_sqs_queue" "notifications" {
  name                       = "${local.name_prefix}-notifications"
  message_retention_seconds  = 1209600  # 14 days
  visibility_timeout_seconds = 60
  delay_seconds              = 0
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-notifications" })
}

resource "aws_sqs_queue" "dlq" {
  name                      = "${local.name_prefix}-dlq"
  message_retention_seconds = 1209600
  visibility_timeout_seconds = 60

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-dlq" })
}

# ═══════════════════════════════════════════
# SNS Topic
# ═══════════════════════════════════════════

resource "aws_sns_topic" "events" {
  name = "${local.name_prefix}-events"

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-events" })
}

# ═══════════════════════════════════════════
# Secrets Manager
# ═══════════════════════════════════════════

resource "aws_secretsmanager_secret" "db_creds" {
  name                    = "${local.name_prefix}/db-creds"
  recovery_window_in_days = var.is_local ? 0 : 30

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db_creds" {
  secret_id = aws_secretsmanager_secret.db_creds.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = aws_db_instance.main.db_name
  })
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "${local.name_prefix}/jwt-secret"
  recovery_window_in_days = var.is_local ? 0 : 30

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id = aws_secretsmanager_secret.jwt_secret.id
  secret_string = jsonencode({
    secret    = var.is_local ? "dev-jwt-secret-key-do-not-use-in-production" : ""
    algorithm = "HS256"
    expiresIn = "24h"
  })
}

# ═══════════════════════════════════════════
# SSM Parameter Store — BFF configuration
# ═══════════════════════════════════════════

resource "aws_ssm_parameter" "environment" {
  name      = "/${var.project_name}/environment"
  type      = "String"
  value     = var.environment
  overwrite = true

  tags = local.common_tags
}

resource "aws_ssm_parameter" "bff_port" {
  name      = "/${var.project_name}/bff/port"
  type      = "String"
  value     = "8080"
  overwrite = true

  tags = local.common_tags
}

resource "aws_ssm_parameter" "elasticache_endpoint" {
  name      = "/${var.project_name}/elasticache/endpoint"
  type      = "String"
  # Dev: MiniStack Redis on localhost:6379 (ElastiCache API is incomplete in MiniStack —
  # TF provider crashes on read-back. The BFF still reads from SSM, same code path.)
  # Prod: Real ElastiCache replication group primary endpoint.
  value     = var.is_local ? "localhost:6379" : aws_elasticache_replication_group.prod[0].primary_endpoint_address
  overwrite = true

  tags = local.common_tags
}

resource "aws_ssm_parameter" "rds_endpoint" {
  name  = "/${var.project_name}/rds/endpoint"
  type  = "String"
  value = "${aws_db_instance.main.address}:${aws_db_instance.main.port}"

  tags = local.common_tags
}

resource "aws_ssm_parameter" "s3_assets_bucket" {
  name  = "/${var.project_name}/s3/assets-bucket"
  type  = "String"
  value = aws_s3_bucket.assets.bucket

  tags = local.common_tags
}

resource "aws_ssm_parameter" "sqs_notifications_url" {
  name  = "/${var.project_name}/sqs/notifications-url"
  type  = "String"
  value = aws_sqs_queue.notifications.url

  tags = local.common_tags
}

# ═══════════════════════════════════════════
# IAM Roles
# ═══════════════════════════════════════════

resource "aws_iam_role" "bff_task" {
  name = "${local.name_prefix}-bff-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-bff-task-role" })
}

resource "aws_iam_role_policy" "bff_permissions" {
  name = "${local.name_prefix}-bff-permissions"
  role = aws_iam_role.bff_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.assets.arn}/*",
          "${aws_s3_bucket.uploads.arn}/*",
          "${aws_s3_bucket.exports.arn}/*",
          aws_s3_bucket.assets.arn,
          aws_s3_bucket.uploads.arn,
          aws_s3_bucket.exports.arn
        ]
      },
      {
        Sid    = "SQSAccess"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [
          aws_sqs_queue.notifications.arn,
          aws_sqs_queue.dlq.arn
        ]
      },
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.db_creds.arn,
          aws_secretsmanager_secret.jwt_secret.arn
        ]
      },
      {
        Sid    = "SSMRead"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = [
          "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/*"
        ]
      }
    ]
  })
}
