# Deploys the app to EKS using the Helm chart. Use this for manual/first-time
# deploys; the GitHub Actions pipeline does the same thing automatically afterwards.
# Usage: .\05-deploy-app-helm.ps1 -Environment "dev" -ImageRepo "<account>.dkr.ecr.ap-south-1.amazonaws.com/autoforge-app" -ImageTag "v1"

param(
    [ValidateSet("dev","prod")][string]$Environment = "dev",
    [Parameter(Mandatory=$true)][string]$ImageRepo,
    [string]$ImageTag = "v1"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

helm upgrade --install autoforge ./helm/automobile-app `
    -f "./helm/automobile-app/values-$Environment.yaml" `
    --set image.repository=$ImageRepo `
    --set image.tag=$ImageTag `
    --namespace $Environment `
    --create-namespace `
    --wait --timeout 5m

Write-Host ""
Write-Host "Deployment complete. Checking rollout..." -ForegroundColor Green
kubectl rollout status deployment/autoforge-app -n $Environment

Write-Host ""
Write-Host "Fetching LoadBalancer hostname (may take 1-3 minutes to appear)..." -ForegroundColor Cyan
kubectl get svc autoforge-lb -n $Environment
