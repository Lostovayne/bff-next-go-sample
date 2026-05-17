# TaskFlow — BFF (Next.js + Go)

> **Arquitectura 2 de 10** — Backend-for-Frontend dentro del repositorio [aws-developer](https://github.com/your-org/aws-developer).

## 🎯 Caso de uso real

TaskFlow es una plataforma **SaaS de gestión de proyectos** (tipo Linear/Jira simplificado) que una startup usaría para gestionar equipos, tareas y sprints. Este patrón BFF existe en producción en empresas como **Vercel**, **Stripe Dashboard**, **Linear**, y **Notion**.

### ¿Por qué BFF y no un monolito?

```
Problema real que resuelve:

  El frontend (Next.js) necesita datos de múltiples fuentes:
  - Base de datos (proyectos, tareas, usuarios)
  - Cache de sesión (auth, preferencias)
  - Archivos adjuntos (S3: screenshots, documentos)
  - Notificaciones asíncronas (SQS: emails, reportes)
  - Webhooks externos (GitHub, Slack integrations)

  Si el frontend llama directo a cada servicio:
  ❌ Lógica de negocio se filtra al cliente
  ❌ Múltiples llamadas por página (N+1 problem)
  ❌ Secrets expuestos en el browser
  ❌ Sin cache centralizado
  ❌ Difícil escalar frontend y backend independientemente

  Con BFF (Go):
  ✅ Un solo endpoint por página → Go agrega todo
  ✅ Auth, rate limiting, caching en un solo lugar
  ✅ Secrets seguros en el backend
  ✅ Frontend y backend escalan por separado
  ✅ El BFF puede evolucionar sin tocar el frontend
```

### Flujo de usuario real

```
Usuario → TaskFlow Dashboard
  │
  ├─ 1. Login → Cognito → sesión en Redis
  │
  ├─ 2. Ver proyecto → Next.js SSR → BFF agrega:
  │     ├─ Datos del proyecto (RDS)
  │     ├─ Tareas recientes con cache (Redis)
  │     ├─ Archivos adjuntos (S3 presigned URLs)
  │     └─ Actividad reciente (EventBridge stream)
  │
  ├─ 3. Crear tarea → BFF valida → RDS → SQS notificación
  │     └─ Worker procesa: email al asignado + Slack webhook
  │
  ├─ 4. Adjuntar screenshot → S3 presigned URL → upload directo
  │
  ├─ 5. Generar reporte semanal → BFF → SQS → Worker → Lambda
  │     └─ Lambda genera PDF → sube a S3 → envía por SES
  │
  └─ 6. Daily summary → EventBridge scheduler → Lambda → SES email
```

## 🏗️ Arquitectura

### Desarrollo local

```
Browser (localhost:3000)
  │
  ├─→ Next.js Dev Server (:3000, hot reload)
  │     │
  │     ├─ SSR: renderiza páginas server-side
  │     ├─ Static: JS/CSS del bundler (Turbopack)
  │     └─ API Routes: /api/* → proxy al BFF
  │           │
  │           └─→ Go BFF (:8080, hot reload con air)
  │                 │
  │                 └─ AWS SDK → MiniStack (:4566)
  │                       │
  │                       ├─ RDS → Postgres real (datos de tareas)
  │                       ├─ ElastiCache → Redis real (sesiones, cache)
  │                       ├─ S3 → buckets (archivos adjuntos)
  │                       ├─ SQS → colas (notificaciones asíncronas)
  │                       ├─ Secrets Manager → DB creds, API keys
  │                       ├─ ECS → containers reales (workers)
  │                       ├─ Lambda → procesamiento de imágenes, reportes
  │                       ├─ EventBridge → scheduled tasks (daily summaries)
  │                       ├─ Step Functions → flujos complejos (onboarding)
  │                       ├─ Cognito → User Pools (auth)
  │                       ├─ CloudWatch → logs y métricas
  │                       └─ ... 60+ servicios AWS emulados
  │
  └─ Todo en tu máquina, un solo puerto :4566
     Sin AWS, sin costo, sin cleanup
```

### Producción AWS (mismo código, solo cambian endpoints)

```
Usuario → CloudFront → ALB → ECS Fargate
  │                           │
  │                           ├─ Go BFF → Aurora PostgreSQL
  │                           ├─ Go BFF → ElastiCache Redis
  │                           ├─ Go BFF → S3 (presigned URLs)
  │                           ├─ Go BFF → SQS → Worker → Lambda
  │                           └─ Go BFF → EventBridge → scheduled tasks
  │
  └─ Mismo Go BFF, mismo Next.js
     Solo cambian variables de entorno
     (de http://ministack:4566 → endpoints reales de AWS)
```

## 📦 Stack tecnológico

| Capa | Tecnología | Propósito |
|------|-----------|-----------|
| **Frontend** | Next.js 16 (App Router), TypeScript 5, React 18 | SSR + SPA, UI del dashboard |
| **State** | TanStack Query 5 | Cache cliente, fetching optimizado |
| **BFF** | Go 1.26, `net/http` stdlib | API aggregation, auth, caching |
| **Dev local** | MiniStack (60+ servicios AWS) | Emulador AWS completo en :4566 |
| **Containers** | Docker + Docker Compose | Reproducibilidad local |
| **Hot reload** | `air` (Go), `next dev` (Next.js) | Desarrollo iterativo rápido |
| **CI/CD** | GitHub Actions | Lint, build, push a GHCR |
| **Infra** | Terraform | VPC, ECS, ALB, Aurora, etc. |
| **Registry** | GitHub Container Registry (ghcr.io) | Imágenes Docker versionadas |

## 📁 Estructura del proyecto

```
bff-next-go-sample/
├── app/
│   ├── nextjs/              # Frontend Next.js (App Router + TS)
│   │   ├── app/
│   │   │   ├── api/hello/   # API route → proxy al BFF
│   │   │   ├── components/  # Componentes React
│   │   │   ├── layout.tsx   # Root layout
│   │   │   └── page.tsx     # Home page
│   │   ├── Dockerfile       # Producción
│   │   ├── Dockerfile.dev   # Desarrollo con hot reload
│   │   └── .npmrc           # Config pnpm (sharp build)
│   └── go-service/          # Backend Go (BFF)
│       ├── main.go          # HTTP server + endpoints
│       ├── Dockerfile       # Producción (scratch image)
│       ├── Dockerfile.dev   # Desarrollo con air
│       └── .air.toml        # Config hot reload Go
├── diagrams/                # Diagramas Mermaid versionados
│   ├── system-context.mmd   # Visión general del sistema
│   ├── container.mmd        # Containers y sus interacciones
│   ├── network.mmd          # VPC, subnets, routing (multi-AZ)
│   ├── deployment.mmd       # Topología de despliegue
│   └── sequence-user-flow.mmd # Flujo de usuario (SSR + hydration + async)
├── terraform/               # Infrastructure as Code (placeholder)
│   ├── backend.tf.example   # S3 + DynamoDB state locking
│   └── variables.tfvars.example
├── .github/workflows/       # CI/CD
├── docker-compose.dev.yml   # Dev: Next.js + Go + MiniStack
├── scripts/                 # Helpers (dev, build, smoke-test)
└── README.md                # Este archivo
```

## 🚀 Desarrollo local

### Requisitos

- Docker + Docker Compose
- Node.js >= 18 (para los scripts raíz)
- Go 1.26+ (solo si querés correr el BFF fuera de Docker)

### Arranque rápido

```bash
# 1. Instalar dependencias raíz
pnpm install

# 2. Instalar dependencias del frontend
cd app/nextjs && pnpm install && cd ../..

# 3. Levantar todo (Next.js + Go BFF + MiniStack)
pnpm run dev
```

Esto ejecuta `docker compose -f docker-compose.dev.yml up --build` y levanta:

| Servicio | URL | Descripción |
|----------|-----|-------------|
| Next.js | http://localhost:3000 | Frontend con hot reload |
| Go BFF | http://localhost:8080 | Backend con hot reload (air) |
| MiniStack | http://localhost:4566 | 60+ servicios AWS emulados |

### Comandos útiles

```bash
# Levantar en dev (con hot reload)
pnpm run dev

# Construir imágenes de producción
pnpm run build-image

# Ejecutar smoke tests
pnpm run smoke-test

# Detener todo
docker compose -f docker-compose.dev.yml down

# Limpiar estado de MiniStack (útil para tests)
curl -X POST http://localhost:4566/_ministack/reset
```

### Verificar que todo funciona

```bash
# Go BFF responde
curl http://localhost:8080/bff/hello
# → {"message":"hello from go bff"}

# Next.js API route proxy al BFF
curl http://localhost:3000/api/hello
# → {"message":"hello from go bff"}

# MiniStack health check
curl http://localhost:4566/_ministack/health
# → {"services": {...}, "status": "running"}
```

## 🔄 CI/CD (GitHub Actions)

```
git push → GitHub Actions
  │
  ├─ 1. lint (ESLint + go vet)
  ├─ 2. build (Docker images)
  ├─ 3. push → ghcr.io/tu-user/bff-{service}:sha
  ├─ 4. MiniStack integration tests (S3, SQS, RDS)
  └─ 5. smoke tests contra servicios locales
```

### Registry

Las imágenes se publican en **GitHub Container Registry** (`ghcr.io`):

```
ghcr.io/tu-user/bff-nextjs:main-abc1234
ghcr.io/tu-user/bff-go:main-abc1234
ghcr.io/tu-user/bff-worker:main-abc1234
```

No necesitás ECR — ghcr.io funciona perfecto con ECS.

## 🏗️ Infraestructura AWS (Terraform)

> ⚠️ En desarrollo usamos MiniStack. Terraform se usa solo cuando deployás a AWS real.

### Servicios que usamos

| Servicio | Uso en TaskFlow | MiniStack | AWS Real |
|----------|----------------|-----------|----------|
| **RDS / Aurora** | Proyectos, tareas, usuarios | ✅ Postgres real | ✅ Aurora PostgreSQL |
| **ElastiCache** | Sesiones, cache de queries | ✅ Redis real | ✅ ElastiCache Redis |
| **S3** | Archivos adjuntos, screenshots | ✅ Buckets, objetos | ✅ S3 + CloudFront |
| **SQS** | Cola de notificaciones | ✅ Colas, FIFO, DLQ | ✅ SQS + DLQ |
| **Secrets Manager** | DB creds, API keys de terceros | ✅ CRUD secrets | ✅ Secrets Manager |
| **ECS Fargate** | Deploy containers | ✅ RunTask real | ✅ ECS Fargate |
| **Lambda** | Procesar imágenes, generar PDFs | ✅ Python real | ✅ Lambda |
| **EventBridge** | Scheduled tasks (daily summary) | ✅ Rules, targets | ✅ EventBridge |
| **Cognito** | Auth de usuarios | ✅ User Pools | ✅ Cognito |
| **CloudWatch** | Logs y métricas | ✅ Logs + Metrics | ✅ CloudWatch |
| **ALB** | Load balancing | ✅ ELBv2 | ✅ ALB |
| **CloudFront** | CDN para assets | ✅ Edge emulation | ✅ CloudFront |

### Estrategia de desarrollo

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

## 📊 Diagramas

Todos los diagramas están en formato Mermaid (`.mmd`) versionados en Git:

| Diagrama | Archivo | Qué muestra |
|----------|---------|-------------|
| System Context | `diagrams/system-context.mmd` | Sistema y dependencias externas |
| Container | `diagrams/container.mmd` | Containers y sus interacciones |
| Network | `diagrams/network.mmd` | VPC, subnets, routing multi-AZ |
| Deployment | `diagrams/deployment.mmd` | Topología de despliegue en ECS |
| Sequence | `diagrams/sequence-user-flow.mmd` | Flujo SSR → hydration → async |

GitHub renderiza Mermaid nativamente — podés verlos directamente en el repo.

## 🎓 Aprendizajes clave

Este proyecto enseña:

1. **Patrón BFF** — Cómo separar frontend de backend de forma limpia
2. **SSR con Next.js** — Server-side rendering + client hydration
3. **Go como BFF** — API aggregation, auth, caching en Go stdlib
4. **AWS local con MiniStack** — 60+ servicios sin cuenta AWS
5. **Docker Compose para dev** — Hot reload en ambos servicios
6. **Infrastructure as Code** — Terraform para AWS real
7. **CI/CD** — GitHub Actions con GHCR
8. **Arquitectura multi-AZ** — Alta disponibilidad desde el diseño
9. **Async processing** — SQS + Worker + Lambda para tareas pesadas
10. **Observability** — CloudWatch logs, metrics, alarms

## 🔧 Troubleshooting

### MiniStack no arranca

```bash
# Verificar que Docker está corriendo
docker ps

# Ver logs de MiniStack
docker logs bff-next-go-sample-ministack-1

# Resetear estado
curl -X POST http://localhost:4566/_ministack/reset
```

### Next.js no conecta al BFF

```bash
# Verificar que el BFF responde
curl http://localhost:8080/bff/hello

# Verificar variable de entorno
docker exec bff-next-go-sample-nextjs-1 env | grep BFF_URL
```

### Go BFF no conecta a MiniStack

```bash
# Verificar que MiniStack está listo
curl http://localhost:4566/_ministack/ready

# Ver logs del BFF
docker logs bff-next-go-sample-go-bff-1
```

## 📝 Licencia

MIT — Este proyecto es parte del repositorio de aprendizaje [aws-developer](https://github.com/your-org/aws-developer).
