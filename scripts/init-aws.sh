#!/bin/bash
# TaskFlow — MiniStack Init Script
# Bootstrap minimal AWS infrastructure for local development
# Run manually: bash scripts/init-aws.sh
# Or mounted at /docker-entrypoint-initaws.d/ in docker-compose

set -euo pipefail

ENDPOINT="${AWS_ENDPOINT_URL:-http://localhost:4566}"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
AWS="--endpoint-url=$ENDPOINT --region=$REGION"

echo "═══════════════════════════════════════════"
echo "  TaskFlow — Local Infrastructure Bootstrap"
echo "  Endpoint: $ENDPOINT"
echo "  Region:   $REGION"
echo "═══════════════════════════════════════════"

# ── S3 Buckets ──
echo ""
echo "📦 S3 Buckets..."

aws $AWS s3 mb s3://taskflow-assets 2>/dev/null || echo "  ⚠ taskflow-assets already exists"
aws $AWS s3 mb s3://taskflow-uploads 2>/dev/null || echo "  ⚠ taskflow-uploads already exists"
aws $AWS s3 mb s3://taskflow-exports 2>/dev/null || echo "  ⚠ taskflow-exports already exists"

echo "  ✓ S3 buckets ready"

# ── SQS Queues ──
echo ""
echo "📨 SQS Queues..."

# Main notifications queue
aws $AWS sqs create-queue \
  --queue-name taskflow-notifications \
  --attributes '{
    "MessageRetentionPeriod": "1209600",
    "VisibilityTimeout": "60",
    "DelaySeconds": "0"
  }' 2>/dev/null || echo "  ⚠ taskflow-notifications already exists"

# Dead letter queue
aws $AWS sqs create-queue \
  --queue-name taskflow-dlq \
  --attributes '{
    "MessageRetentionPeriod": "1209600",
    "VisibilityTimeout": "60"
  }' 2>/dev/null || echo "  ⚠ taskflow-dlq already exists"

# Get DLQ ARN for redrive policy
DLQ_ARN=$(aws $AWS sqs get-queue-attributes \
  --queue-url "$ENDPOINT/000000000000/taskflow-dlq" \
  --attribute-names QueueArn \
  --query 'Attributes.QueueArn' --output text 2>/dev/null || echo "")

if [ -n "$DLQ_ARN" ]; then
  # Set redrive policy on main queue
  aws $AWS sqs set-queue-attributes \
    --queue-url "$ENDPOINT/000000000000/taskflow-notifications" \
    --attributes "{\"RedrivePolicy\":\"{\\\"deadLetterTargetArn\\\":\\\"$DLQ_ARN\\\",\\\"maxReceiveCount\\\":\\\"3\\\"}\"}" 2>/dev/null || true
  echo "  ✓ Redrive policy configured (maxReceiveCount: 3)"
fi

echo "  ✓ SQS queues ready"

# ── SNS Topic ──
echo ""
echo "📢 SNS Topics..."

aws $AWS sns create-topic \
  --name taskflow-events 2>/dev/null || echo "  ⚠ taskflow-events already exists"

echo "  ✓ SNS topics ready"

# ── Secrets Manager ──
echo ""
echo "🔐 Secrets Manager..."

aws $AWS secretsmanager create-secret \
  --name taskflow/db-creds \
  --secret-string '{"username":"taskflow_admin","password":"dev-password-123","host":"localhost","port":"5432","dbname":"taskflow"}' \
  2>/dev/null || echo "  ⚠ taskflow/db-creds already exists"

aws $AWS secretsmanager create-secret \
  --name taskflow/jwt-secret \
  --secret-string '{"secret":"dev-jwt-secret-key-do-not-use-in-production","algorithm":"HS256","expiresIn":"24h"}' \
  2>/dev/null || echo "  ⚠ taskflow/jwt-secret already exists"

aws $AWS secretsmanager create-secret \
  --name taskflow/api-keys \
  --secret-string '{"stripe":"sk_test_dev","sendgrid":"SG.dev-key","slack":"xoxb-dev-key"}' \
  2>/dev/null || echo "  ⚠ taskflow/api-keys already exists"

echo "  ✓ Secrets ready"

# ── DynamoDB Tables ──
echo ""
echo "🗄️  DynamoDB Tables..."

# Sessions table
aws $AWS dynamodb create-table \
  --table-name taskflow-sessions \
  --attribute-definitions AttributeName=sessionId,AttributeType=S \
  --key-schema AttributeName=sessionId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --tags Key=Project,Value=TaskFlow 2>/dev/null || echo "  ⚠ taskflow-sessions already exists"

# Feature flags table
aws $AWS dynamodb create-table \
  --table-name taskflow-feature-flags \
  --attribute-definitions \
    AttributeName=flagKey,AttributeType=S \
    AttributeName=environment,AttributeType=S \
  --key-schema \
    AttributeName=flagKey,KeyType=HASH \
    AttributeName=environment,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --tags Key=Project,Value=TaskFlow 2>/dev/null || echo "  ⚠ taskflow-feature-flags already exists"

echo "  ✓ DynamoDB tables ready"

# ── Parameter Store (SSM) ──
echo ""
echo "⚙️  SSM Parameter Store..."

aws $AWS ssm put-parameter \
  --name "/taskflow/environment" \
  --value "development" \
  --type String \
  --overwrite 2>/dev/null || echo "  ⚠ /taskflow/environment already exists"

aws $AWS ssm put-parameter \
  --name "/taskflow/bff/port" \
  --value "8080" \
  --type String \
  --overwrite 2>/dev/null || echo "  ⚠ /taskflow/bff/port already exists"

aws $AWS ssm put-parameter \
  --name "/taskflow/elasticache/endpoint" \
  --value "localhost:6379" \
  --type String \
  --overwrite 2>/dev/null || echo "  ⚠ /taskflow/elasticache/endpoint already exists"

echo "  ✓ SSM parameters ready"

# ── Summary ──
echo ""
echo "═══════════════════════════════════════════"
echo "  ✅ TaskFlow infrastructure is ready!"
echo "═══════════════════════════════════════════"
echo ""
echo "  S3 Buckets:"
echo "    • taskflow-assets"
echo "    • taskflow-uploads"
echo "    • taskflow-exports"
echo ""
echo "  SQS Queues:"
echo "    • taskflow-notifications (→ DLQ after 3 retries)"
echo "    • taskflow-dlq"
echo ""
echo "  SNS Topics:"
echo "    • taskflow-events"
echo ""
echo "  Secrets:"
echo "    • taskflow/db-creds"
echo "    • taskflow/jwt-secret"
echo "    • taskflow/api-keys"
echo ""
echo "  DynamoDB:"
echo "    • taskflow-sessions"
echo "    • taskflow-feature-flags"
echo ""
echo "  SSM Parameters:"
echo "    • /taskflow/environment"
echo "    • /taskflow/bff/port"
echo "    • /taskflow/elasticache/endpoint"
echo ""
