# Builds the Docker image and pushes it to ECR.
# Usage: .\04-build-and-push-image.ps1 -Region "ap-south-1" -RepoName "autoforge-app" -Tag "v1"

param(
    [string]$Region = "ap-south-1",
    [string]$RepoName = "autoforge-app",
    [string]$Tag = "v1"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

$accountId = aws sts get-caller-identity --query "Account" --output text
$registry = "$accountId.dkr.ecr.$Region.amazonaws.com"
$imageUri = "$registry/${RepoName}:$Tag"

Write-Host "Logging in to ECR: $registry" -ForegroundColor Cyan
aws ecr get-login-password --region $Region | docker login --username AWS --password-stdin $registry

Write-Host "Building image: $imageUri" -ForegroundColor Cyan
docker build -t $imageUri -t "$registry/${RepoName}:latest" "$root\app"

Write-Host "Pushing image to ECR..." -ForegroundColor Cyan
docker push $imageUri
docker push "$registry/${RepoName}:latest"

Write-Host ""
Write-Host "Image pushed: $imageUri" -ForegroundColor Green
Write-Host "Use this image URI in your Helm command or Kubernetes manifests." -ForegroundColor Yellow
