# This is a reminder script (GitHub secrets must be set via the GitHub UI or gh CLI).
# If you have GitHub CLI (gh) installed and authenticated, this will set the secret for you.
# Usage: .\07-set-github-secrets-reminder.ps1 -RoleArn "arn:aws:iam::123456789012:role/autoforge-github-actions-role" -Repo "your-username/automobile-app-eks-kubernetes-deployment"

param(
    [Parameter(Mandatory=$true)][string]$RoleArn,
    [Parameter(Mandatory=$true)][string]$Repo
)

$ghInstalled = Get-Command gh -ErrorAction SilentlyContinue
if ($ghInstalled) {
    gh secret set AWS_GITHUB_ACTIONS_ROLE_ARN --body $RoleArn --repo $Repo
    Write-Host "Secret AWS_GITHUB_ACTIONS_ROLE_ARN set on $Repo" -ForegroundColor Green
} else {
    Write-Host "GitHub CLI (gh) not found. Set this manually:" -ForegroundColor Yellow
    Write-Host "  Repo Settings -> Secrets and variables -> Actions -> New repository secret"
    Write-Host "  Name:  AWS_GITHUB_ACTIONS_ROLE_ARN"
    Write-Host "  Value: $RoleArn"
}
