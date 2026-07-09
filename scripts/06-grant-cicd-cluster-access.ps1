# Grants the GitHub Actions IAM role permission to manage the EKS cluster.
# Required once, after terraform apply, because IAM role trust alone doesn't
# grant Kubernetes RBAC permissions.
# Usage: .\06-grant-cicd-cluster-access.ps1 -ClusterName "autoforge-eks" -RoleArn "arn:aws:iam::123456789012:role/autoforge-github-actions-role"

param(
    [string]$ClusterName = "autoforge-eks",
    [Parameter(Mandatory=$true)][string]$RoleArn
)

Write-Host "Creating EKS access entry for CI/CD role..." -ForegroundColor Cyan
aws eks create-access-entry `
    --cluster-name $ClusterName `
    --principal-arn $RoleArn `
    --type STANDARD

Write-Host "Associating cluster-admin access policy..." -ForegroundColor Cyan
aws eks associate-access-policy `
    --cluster-name $ClusterName `
    --principal-arn $RoleArn `
    --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy `
    --access-scope type=cluster

Write-Host ""
Write-Host "CI/CD role can now manage the cluster." -ForegroundColor Green
