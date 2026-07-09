# Runs the seed Job (creates the `vehicles` table and inserts starter rows).
# Safe to re-run - seed.py skips inserting if rows already exist.
# Usage: .\09-seed-database.ps1 -Environment "dev" -Image "<account>.dkr.ecr.ap-south-1.amazonaws.com/autoforge-app:v1"

param(
    [ValidateSet("dev","prod")][string]$Environment = "dev",
    [Parameter(Mandatory=$true)][string]$Image
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$jobFile = Join-Path $root "k8s\$Environment\seed-job.yaml"

Write-Host "Deleting any previous seed Job (Jobs can't be updated in place)..." -ForegroundColor Cyan
kubectl delete job autoforge-seed -n $Environment --ignore-not-found

Write-Host "Applying seed Job with image: $Image" -ForegroundColor Cyan
(Get-Content $jobFile) -replace 'image: .*', "image: $Image" | kubectl apply -f -

Write-Host "Waiting for the seed Job to complete..." -ForegroundColor Cyan
kubectl wait --for=condition=complete job/autoforge-seed -n $Environment --timeout=120s

Write-Host ""
Write-Host "Seed Job logs:" -ForegroundColor Green
kubectl logs job/autoforge-seed -n $Environment
