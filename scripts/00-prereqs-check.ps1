# Checks that all required CLI tools are installed before you start.
# Run from PowerShell: .\00-prereqs-check.ps1

$tools = @("aws", "terraform", "kubectl", "helm", "docker")
$missing = @()

foreach ($tool in $tools) {
    $found = Get-Command $tool -ErrorAction SilentlyContinue
    if ($found) {
        Write-Host "[OK] $tool found: $($found.Source)" -ForegroundColor Green
    } else {
        Write-Host "[MISSING] $tool not found in PATH" -ForegroundColor Red
        $missing += $tool
    }
}

if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Host "Install missing tools before continuing:" -ForegroundColor Yellow
    Write-Host "  AWS CLI     : https://awscli.amazonaws.com/AWSCLIV2.msi"
    Write-Host "  Terraform   : choco install terraform   (or https://developer.hashicorp.com/terraform/downloads)"
    Write-Host "  kubectl     : choco install kubernetes-cli"
    Write-Host "  Helm        : choco install kubernetes-helm"
    Write-Host "  Docker      : https://www.docker.com/products/docker-desktop/"
    exit 1
} else {
    Write-Host ""
    Write-Host "All required tools are installed." -ForegroundColor Green
}

Write-Host ""
Write-Host "Checking AWS credentials..." -ForegroundColor Cyan
aws sts get-caller-identity
