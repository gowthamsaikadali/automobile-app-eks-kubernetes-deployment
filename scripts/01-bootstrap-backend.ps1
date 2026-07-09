# Creates the S3 bucket + DynamoDB table used for Terraform remote state.
# Run ONCE, before terraform init.
# Usage: .\01-bootstrap-backend.ps1 -BucketName "autoforge-tfstate-yourname123" -Region "ap-south-1"

param(
    [Parameter(Mandatory=$true)][string]$BucketName,
    [string]$Region = "ap-south-1",
    [string]$DynamoTable = "autoforge-tf-lock"
)

Write-Host "Creating S3 bucket: $BucketName in $Region" -ForegroundColor Cyan
aws s3api create-bucket `
    --bucket $BucketName `
    --region $Region `
    --create-bucket-configuration LocationConstraint=$Region

Write-Host "Enabling versioning on the bucket..." -ForegroundColor Cyan
aws s3api put-bucket-versioning `
    --bucket $BucketName `
    --versioning-configuration Status=Enabled

Write-Host "Blocking public access on the bucket..." -ForegroundColor Cyan
aws s3api put-public-access-block `
    --bucket $BucketName `
    --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

Write-Host "Creating DynamoDB lock table: $DynamoTable" -ForegroundColor Cyan
aws dynamodb create-table `
    --table-name $DynamoTable `
    --attribute-definitions AttributeName=LockID,AttributeType=S `
    --key-schema AttributeName=LockID,KeyType=HASH `
    --billing-mode PAY_PER_REQUEST `
    --region $Region

Write-Host ""
Write-Host "Backend resources created." -ForegroundColor Green
Write-Host "Now edit terraform/versions.tf and uncomment the S3 backend block, replacing the bucket name with: $BucketName" -ForegroundColor Yellow
