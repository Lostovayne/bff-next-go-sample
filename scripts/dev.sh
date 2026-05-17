#!/usr/bin/env bash
set -euo pipefail

# Levanta servicios en modo dev con docker-compose
docker-compose -f docker-compose.dev.yml up --build
