# Points your local kubectl at the new EKS cluster.
# Usage: .\03-configure-kubectl.ps1 -Region "ap-south-1" -ClusterName "autoforge-eks"

param(
    [string]$Region = "ap-south-1",
    [string]$ClusterName = "autoforge-eks"
)

aws eks update-kubeconfig --region $Region --name $ClusterName

Write-Host ""
Write-Host "Verifying connection to the cluster..." -ForegroundColor Cyan
kubectl get nodes
kubectl cluster-info
