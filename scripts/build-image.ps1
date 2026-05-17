Param()
Set-StrictMode -Version Latest

Write-Host "Building Docker images..."

docker build -t bff-nextjs:local ./app/nextjs
docker build -t bff-go:local ./app/go-service

Write-Host "Built images: bff-nextjs:local, bff-go:local"
