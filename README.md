# BFF (Next.js + Go)

## Propósito

Proyecto minimal para aprender a desarrollar, ejecutar localmente y luego desplegar una arquitectura BFF: Next.js (App Router, TypeScript, TanStack Query) como frontend/SSR y Go como Backend‑for‑Frontend (BFF) que orquesta llamadas a servicios.

## Alcance del scaffold

- Código "app first": ejemplo mínimo de Next.js (TS) + Go HTTP service
- Dockerfiles para ambos servicios
- docker-compose.dev.yml para correr ambos en local
- Diagramas en mermaid para system/container/sequence/deployment/network (editable)
- GitHub Actions workflow de CI que hace lint/test y build
- Terraform placeholders (backend.example + variables example)
- Scripts de ayuda (dev, build-image, smoke-test)

## Decisiones y convenciones

- Next.js App Router (app/) y TypeScript
- TanStack Query para caché cliente y fetching
- Go net/http mínimo para endpoints BFF /bff/\*
- Docker para reproducibilidad; deploy target: AWS Fargate (ECS)
- CI: GitHub Actions (jobs: lint/test, build image, optional push)

## Estructura importante

- app/nextjs/ → Next.js app
- app/go-service/ → Go BFF
- diagrams/ → Mermaid diagrams (.mmd)
- terraform/ → placeholders para infra
- .github/workflows/ → CI (ci.yaml)
- docker-compose.dev.yml → dev compose
- scripts/ → helpers

## Cómo arrancar en local (dev)

Requisitos: Node, npm/yarn, Go, Docker, docker-compose

Cross-platform (recomendado)

1. Instala dependencias y usa pnpm. Recomendado: instala dependencias en los subproyectos antes de ejecutar los scripts.

Instalación y arranque (recomendado):

## 1) En la raíz (scripts Node cross-platform)

pnpm install

## 2) Instala dependencias del frontend (Next.js)

cd app/nextjs
pnpm install

## 3) Volver a la raíz y levantar en dev:

cd ../..
pnpm run dev

Esto ejecuta docker-compose y levanta los servicios (Next en http://localhost:3000, Go en http://localhost:8080).

Comandos útiles (pnpm):

- Levantar en dev: pnpm run dev
- Construir imágenes localmente: pnpm run build-image
- Ejecutar tests de humo: pnpm run smoke-test

Opciones manuales / alternativas

Docker Compose (manual):

- docker-compose -f docker-compose.dev.yml up --build

Linux / macOS / WSL / Git Bash

Si preferís usar los scripts .sh en lugar de npm scripts:
./scripts/dev.sh
./scripts/build-image.sh
./scripts/smoke-test.sh

Windows (PowerShell)

Si preferís usar los scripts PowerShell incluidos:
.\scripts\dev.ps1
.\scripts\build-image.ps1
.\scripts\smoke-test.ps1

Notas:

- Los pnpm scripts usan Node >= 18 (ver package.json "engines"). Si no tenés Node 18+, podés usar WSL o instalar Node LTS.
- Ejecutar PowerShell con permisos suficientes para Docker. Para permitir la ejecución de scripts .ps1 puede que necesites ajustar ExecutionPolicy (ej: Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned) — hacelo con precaución.
- Los scripts Node son cross-platform y evitan la necesidad de editar .ps1/.sh para la mayoría de usos.

## Siguientes pasos para deploy (infra-as-code)

- Añadir terraform/infra para: VPC, subnets, ECS cluster, ECR, ALB, IAM roles, CloudFront
- Añadir CI step para terraform plan/apply con un runner controlado o Terraform Cloud

## Notas

- No hay secretos en el repo. Configura GHCR or ECR credentials en GitHub Secrets si querés empujar images.
- Este scaffold es punto de partida para experimentar deploys en AWS y entender la integración entre Next y Go BFF.
