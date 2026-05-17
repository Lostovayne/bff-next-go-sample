Param()
Set-StrictMode -Version Latest

$ErrorActionPreference = 'Stop'
try {
    $resp = Invoke-RestMethod -Uri http://localhost:8080/bff/hello -UseBasicParsing -TimeoutSec 5
    if ($resp.message -like '*hello*') { Write-Host 'Go BFF OK' } else { Write-Error 'Go BFF failed' }
} catch {
    Write-Error "Go BFF failed: $_"
    exit 1
}

try {
    $resp2 = Invoke-RestMethod -Uri http://localhost:3000/ -UseBasicParsing -TimeoutSec 5
    Write-Host 'Next OK'
} catch {
    Write-Error "Next failed: $_"
    exit 1
}

Write-Host 'Smoke tests passed'
