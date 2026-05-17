# ── Environment ──
variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "taskflow"
}

# ── AWS Provider ──
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_endpoint" {
  description = "AWS service endpoint override. Set to http://localhost:4566 for MiniStack, empty string for real AWS"
  type        = string
  default     = ""
}

variable "is_local" {
  description = "Whether we're running against a local emulator (MiniStack). Controls credential skipping and path-style S3"
  type        = bool
  default     = false
}

# ── Networking ──
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for multi-AZ deployment"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# ── Database ──
variable "db_username" {
  description = "Master username for RDS Aurora PostgreSQL"
  type        = string
  default     = "taskflow_admin"
  sensitive   = true
}

variable "db_password" {
  description = "Master password for RDS. In prod, use Secrets Manager or SSM"
  type        = string
  sensitive   = true
  default     = "dev-password-123"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

# ── ElastiCache ──
variable "cache_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t4g.micro"
}

variable "cache_num_nodes" {
  description = "Number of ElastiCache nodes"
  type        = number
  default     = 1
}

# ── ECS / Compute ──
variable "bff_cpu" {
  description = "CPU units for the BFF task (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "bff_memory" {
  description = "Memory in MiB for the BFF task"
  type        = number
  default     = 512
}

variable "bff_image" {
  description = "Docker image for the Go BFF service"
  type        = string
  default     = "go-bff:dev"
}

variable "nextjs_image" {
  description = "Docker image for the Next.js frontend"
  type        = string
  default     = "nextjs:dev"
}

# ── Tags ──
variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
