# Alternative to Helm: deploys the app using plain kubectl apply against the
# raw manifests in k8s/dev or k8s/prod. Edit the deployment.yaml image field
# first, or use -Image to patch it automatically.
# Usage: .\05b-deploy-app-raw-manifests.ps1 -Environment "dev" -Image "<account>.dkr.ecr.ap-south-1.amazonaws.com/autoforge-app:v1"

param(
    [ValidateSet("dev","prod")][string]$Environment = "dev",
    [Parameter(Mandatory=$true)][string]$Image
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$manifestDir = Join-Path $root "k8s\$Environment"

Write-Host "Applying namespace..." -ForegroundColor Cyan
kubectl apply -f "$root\k8s\namespaces.yaml"

Write-Host "Applying ConfigMap and Secret..." -ForegroundColor Cyan
kubectl apply -f "$manifestDir\configmap.yaml"
kubectl apply -f "$manifestDir\secret.yaml"
kubectl apply -f "$manifestDir\serviceaccount.yaml"

Write-Host "Patching image reference and applying Deployment..." -ForegroundColor Cyan
(Get-Content "$manifestDir\deployment.yaml") -replace 'image: .*', "image: $Image" | kubectl apply -f -

Write-Host "Applying Services, Ingress, and HPA..." -ForegroundColor Cyan
kubectl apply -f "$manifestDir\service-clusterip.yaml"
kubectl apply -f "$manifestDir\service-loadbalancer.yaml"
kubectl apply -f "$manifestDir\hpa.yaml"
# Ingress requires the AWS Load Balancer Controller (see docs\aws-load-balancer-controller.md)
# kubectl apply -f "$manifestDir\ingress.yaml"

Write-Host ""
Write-Host "Checking rollout..." -ForegroundColor Green
kubectl rollout status deployment/autoforge-app -n $Environment
kubectl get all -n $Environment
