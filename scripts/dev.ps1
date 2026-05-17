Param()
Set-StrictMode -Version Latest

Write-Host "Starting Docker Compose (dev) ..."
docker-compose -f docker-compose.dev.yml up --build
