#!/usr/bin/env bash
set -euo pipefail

# Build images locally
docker build -t bff-nextjs:local ./app/nextjs
docker build -t bff-go:local ./app/go-service

echo "Built images: bff-nextjs:local, bff-go:local"
