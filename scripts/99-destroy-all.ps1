# IMPORTANT (free trial cost control): deletes the Helm release, LoadBalancer
# services, and then all Terraform-managed AWS infrastructure (EKS, NAT Gateway,
# VPC, ECR). Run this as soon as you're done with the project to avoid charges.
# Usage: .\99-destroy-all.ps1

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot

Write-Host "Step 1: Deleting Helm releases (removes LoadBalancer/ALB first, avoids orphaned ELBs)..." -ForegroundColor Cyan
helm uninstall autoforge -n dev 2>$null
helm uninstall autoforge -n prod 2>$null

Write-Host "Step 2: Deleting any remaining LoadBalancer services / ingresses..." -ForegroundColor Cyan
kubectl delete svc autoforge-lb -n dev --ignore-not-found
kubectl delete svc autoforge-lb -n prod --ignore-not-found
kubectl delete ingress autoforge-ingress -n dev --ignore-not-found
kubectl delete ingress autoforge-ingress -n prod --ignore-not-found

Write-Host "Waiting 60 seconds for AWS to finish deleting the load balancer(s)..." -ForegroundColor Yellow
Start-Sleep -Seconds 60

Write-Host "Step 3: Running terraform destroy (this removes EKS, NAT Gateway, VPC, ECR)..." -ForegroundColor Cyan
Set-Location "$root\terraform"
terraform destroy

Write-Host ""
Write-Host "Step 4: Manually verify in the AWS Console that nothing is left running:" -ForegroundColor Yellow
Write-Host "  - EC2 > Load Balancers"
Write-Host "  - EC2 > NAT Gateways / Elastic IPs"
Write-Host "  - EKS > Clusters"
Write-Host "  - ECR > Repositories"
Write-Host "  - VPC > Your VPCs"
Write-Host ""
Write-Host "If you created the S3 state bucket / DynamoDB lock table, delete them too if no longer needed:" -ForegroundColor Yellow
Write-Host "  aws s3 rb s3://YOUR-BUCKET-NAME --force"
Write-Host "  aws dynamodb delete-table --table-name autoforge-tf-lock"
