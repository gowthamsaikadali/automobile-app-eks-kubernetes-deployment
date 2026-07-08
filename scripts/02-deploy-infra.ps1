# Runs Terraform init/plan/apply for the VPC + EKS + ECR infrastructure.
# Run from the project root or this scripts folder; it will cd into terraform/.
# Usage: .\02-deploy-infra.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location "$root\terraform"

if (-not (Test-Path "terraform.tfvars")) {
    Write-Host "terraform.tfvars not found. Copying from terraform.tfvars.example..." -ForegroundColor Yellow
    Copy-Item "terraform.tfvars.example" "terraform.tfvars"
    Write-Host "IMPORTANT: edit terraform\terraform.tfvars now and set github_oidc_repo to your-username/your-repo." -ForegroundColor Yellow
    Write-Host "Press Enter once you've edited it, or Ctrl+C to stop."
    Read-Host
}

Write-Host "Running terraform init..." -ForegroundColor Cyan
terraform init

Write-Host "Running terraform plan..." -ForegroundColor Cyan
terraform plan -out=tfplan

Write-Host ""
Write-Host "Review the plan above." -ForegroundColor Yellow
$confirm = Read-Host "Type 'yes' to apply this plan"
if ($confirm -ne "yes") {
    Write-Host "Aborted." -ForegroundColor Red
    exit 1
}

terraform apply tfplan

Write-Host ""
Write-Host "Infrastructure created. Fetching outputs..." -ForegroundColor Green
terraform output
