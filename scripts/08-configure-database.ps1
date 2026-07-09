# Pulls the real RDS endpoint from Terraform outputs and creates/updates the
# ConfigMap + Secret in the target namespace with the correct DB_HOST and
# DB_PASSWORD - no manual YAML editing needed.
# Usage: .\08-configure-database.ps1 -Environment "dev" -DbPassword "YourStrongPassword123!"

param(
    [ValidateSet("dev","prod")][string]$Environment = "dev",
    [Parameter(Mandatory=$true)][string]$DbPassword
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

Write-Host "Reading RDS endpoint from Terraform outputs..." -ForegroundColor Cyan
Push-Location "$root\terraform"
$dbAddress = terraform output -raw db_address
$dbPort = terraform output -raw db_port
$dbName = terraform output -raw db_name
Pop-Location

if (-not $dbAddress) {
    Write-Host "Could not read db_address from terraform output. Did you run terraform apply?" -ForegroundColor Red
    exit 1
}

Write-Host "DB endpoint: $dbAddress`:$dbPort/$dbName" -ForegroundColor Green

Write-Host "Ensuring namespace '$Environment' exists..." -ForegroundColor Cyan
kubectl create namespace $Environment --dry-run=client -o yaml | kubectl apply -f -

Write-Host "Creating/updating ConfigMap autoforge-config in namespace $Environment..." -ForegroundColor Cyan
kubectl create configmap autoforge-config `
    --from-literal=APP_NAME="AutoForge Dashboard" `
    --from-literal=APP_ENV="$Environment" `
    --from-literal=APP_VERSION="2.0.0" `
    --from-literal=DB_HOST="$dbAddress" `
    --from-literal=DB_PORT="$dbPort" `
    --from-literal=DB_NAME="$dbName" `
    --from-literal=DB_USER="autoforge_admin" `
    --from-literal=FEATURE_FLAG_DARK_MODE="$(if ($Environment -eq 'dev') { 'true' } else { 'false' })" `
    --namespace $Environment `
    --dry-run=client -o yaml | kubectl apply -f -

Write-Host "Creating/updating Secret autoforge-secret in namespace $Environment..." -ForegroundColor Cyan
kubectl create secret generic autoforge-secret `
    --from-literal=DB_PASSWORD="$DbPassword" `
    --namespace $Environment `
    --dry-run=client -o yaml | kubectl apply -f -

Write-Host ""
Write-Host "ConfigMap and Secret configured for namespace '$Environment'." -ForegroundColor Green
Write-Host "If a Deployment already exists, restart it to pick up the new values:" -ForegroundColor Yellow
Write-Host "  kubectl rollout restart deployment/autoforge-app -n $Environment"
