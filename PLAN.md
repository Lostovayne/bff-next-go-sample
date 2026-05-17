# TaskFlow — Implementation Plan

> Architecture 2: BFF (Next.js + Go) — Part of aws-developer repo

## 🎯 Project Context

TaskFlow is a SaaS project management tool (Linear/Jira simplified). This BFF architecture exists in production at companies like Vercel, Stripe Dashboard, Linear, and Notion.

## 📋 4-Phase Implementation Plan

### Phase 1: docker-compose.dev.yml with MiniStack

```
docker compose up
  │
  ├─→ nextjs (:3000, hot reload)
  │     └─ Volume mount: ./app/nextjs:/app
  │
  ├─→ go-bff (:8080, hot reload con air)
  │     └─ Volume mount: ./app/go-service:/src
  │     └─ AWS SDK → http://ministack:4566
  │
  ├─→ ministack (:4566, 60+ servicios AWS)
  │     ├─ Docker socket mount → containers reales
  │     ├─ DOCKER_NETWORK → red compartida
  │     ├─ REDIS_HOST=redis → sidecar Redis
  │     ├─ PERSIST_STATE=1 → estado entre reinicios
  │     └─ Init scripts → crea infra al arrancar:
  │           ├─ S3 bucket: taskflow-assets
  │           ├─ SQS queue: taskflow-notifications
  │           ├─ Secrets: db-creds, api-keys
  │           └─ DynamoDB table: sessions (si aplica)
  │
  └─→ redis (:6379, sidecar)
        └─ Cache de sesiones, queries frecuentes
```

**Files to create/modify:**
- `docker-compose.dev.yml` — Add MiniStack + Redis services
- `scripts/init-aws.sh` — Init scripts for MiniStack bootstrap

### Phase 2: Terraform Base (MiniStack + AWS Real)

```
terraform/
  │
  ├─ provider.tf
  │     └─ Provider "aws" con variable para endpoint_url
  │        → Si endpoint = http://localhost:4566 → MiniStack
  │        → Si endpoint = "" → AWS real
  │
  ├─ backend.tf.example
  │     └─ S3 backend con use_lockfile = true (NO DynamoDB)
  │        → Para dev: backend "local"
  │
  ├─ main.tf
  │     └─ Recursos de TaskFlow:
  │           ├─ VPC, subnets (public/private/isolated)
  │           ├─ Security groups
  │           ├─ RDS (Aurora PostgreSQL)
  │           ├─ ElastiCache (Redis)
  │           ├─ S3 bucket (taskflow-assets)
  │           ├─ SQS queue (taskflow-notifications + DLQ)
  │           ├─ Secrets Manager (db-creds)
  │           ├─ ECS cluster + task definitions
  │           ├─ ALB + target groups
  │           └─ IAM roles/policies
  │
  ├─ variables.tf
  │     └─ environment, endpoint_url, db_password, etc.
  │
  ├─ outputs.tf
  │     └─ ALB DNS, RDS endpoint, S3 bucket name, etc.
  │
  ├─ dev.tfvars.example
  │     └─ endpoint_url = "http://localhost:4566"
  │        environment = "dev"
  │        db_password = "dev-password"
  │
  └─ prod.tfvars.example
        └─ endpoint_url = "" (AWS real)
           environment = "prod"
           db_password = "${secretsmanager}"
```

**Key Terraform config:**
```hcl
# S3 Backend with native locking (NO DynamoDB)
terraform {
  backend "s3" {
    bucket       = "taskflow-terraform-state"
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true  # S3 native locking - TF 1.10+
  }
}
```

**Files to create:**
- `terraform/provider.tf`
- `terraform/backend.tf.example`
- `terraform/main.tf`
- `terraform/variables.tf`
- `terraform/outputs.tf`
- `terraform/dev.tfvars.example`
- `terraform/prod.tfvars.example`

### Phase 3: Go BFF AWS SDK Integration

```
app/go-service/
  │
  ├─ go.mod
  │     └─ Agregar: github.com/aws/aws-sdk-go-v2 + servicios
  │
  ├─ internal/
  │     ├─ config/
  │     │     └─ Load AWS config (endpoint override si dev)
  │     ├─ database/
  │     │     └─ RDS connection pool
  │     ├─ cache/
  │     │     └─ Redis client (ElastiCache)
  │     ├─ storage/
  │     │     └─ S3 client (presigned URLs)
  │     ├─ queue/
  │     │     └─ SQS client (send messages)
  │     └─ secrets/
  │           └─ Secrets Manager client (get db creds)
  │
  └─ main.go
        └─ HTTP handlers que usan los clientes de arriba
```

**Example endpoint flow:**
```
GET /bff/projects/:id
  │
  ├─ 1. Cache check → Redis (si hit → return)
  ├─ 2. Cache miss → RDS query
  ├─ 3. Get presigned URLs for attachments → S3
  ├─ 4. Store in cache → Redis (TTL 5min)
  └─ 5. Return JSON
```

**Files to create/modify:**
- `app/go-service/go.mod` — Add AWS SDK v2 dependencies
- `app/go-service/internal/config/config.go`
- `app/go-service/internal/database/database.go`
- `app/go-service/internal/cache/cache.go`
- `app/go-service/internal/storage/storage.go`
- `app/go-service/internal/queue/queue.go`
- `app/go-service/internal/secrets/secrets.go`
- `app/go-service/main.go` — Update with new handlers

### Phase 4: MiniStack Init Scripts (Optional Bootstrap)

```
scripts/init-aws.sh (se monta en /docker-entrypoint-initaws.d/)
  │
  ├─ aws s3 mb s3://taskflow-assets
  ├─ aws sqs create-queue --queue-name taskflow-notifications
  ├─ aws sqs create-queue --queue-name taskflow-dlq
  ├─ aws secretsmanager create-secret \
  │     --name taskflow/db-creds \
  │     --secret-string '{"username":"admin","password":"dev"}'
  ├─ aws dynamodb create-table \
  │     --table-name sessions \
  │     --key-schema AttributeName=sessionId,KeyType=HASH
  └─ echo "✓ TaskFlow infrastructure ready"
```

**Purpose:** Bootstrap minimal infra for local dev without running Terraform first. Useful for quick local testing.

**Files to create:**
- `scripts/init-aws.sh` — Init script for MiniStack

## 🔄 CI/CD Flow

```
git push → GitHub Actions
  │
  ├─ 1. lint (ESLint + go vet)
  ├─ 2. build (Docker images)
  ├─ 3. push → ghcr.io/tu-user/bff-{service}:sha
  ├─ 4. MiniStack integration tests (S3, SQS, RDS)
  └─ 5. smoke tests contra servicios locales
```

## 📊 Architecture Strategy

```
Fase 1 — AHORA (MiniStack local):
  │
  ├─ docker compose: Next.js + Go BFF + MiniStack
  ├─ El BFF usa AWS SDK → http://ministack:4566
  ├─ Probás TODO local: RDS, Redis, S3, SQS, Lambda, EventBridge, Cognito
  ├─ CI: lint + build + tests contra MiniStack
  └─ Cero costo, cero cleanup, 60+ servicios

Fase 2 — DESPUÉS (AWS real):
  │
  ├─ Terraform para infraestructura real
  ├─ GitHub Actions: build → push ghcr.io → terraform apply
  ├─ Mismo código, solo cambian variables de entorno
  └─ Solo para servicios que MiniStack no soporte bien
```

## 📝 Notes

- User prefers ASCII-art tree diagrams for flows
- MiniStack is the default AWS emulator for all projects in aws-developer
- TaskFlow = SaaS project management tool (Linear/Jira simplified)
- Terraform S3 backend uses `use_lockfile = true` (native S3 locking, NO DynamoDB)
- For dev: backend "local" (file-based state), for prod: backend "s3" with `use_lockfile = true`
