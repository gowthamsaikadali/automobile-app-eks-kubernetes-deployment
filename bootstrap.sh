#!/usr/bin/env bash
# Run this ONCE, before the first terraform init. Creates the state bucket
# and lock table that backend.tf depends on. Safe to re-run — checks first.
set -euo pipefail

REGION="ap-south-1"
BUCKET="autoforge-eks-tfstate"
TABLE="autoforge-eks-tf-lock"

if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "Bucket $BUCKET already exists, skipping."
else
  aws s3 mb "s3://$BUCKET" --region "$REGION"
  aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled
fi

if aws dynamodb describe-table --table-name "$TABLE" --region "$REGION" >/dev/null 2>&1; then
  echo "Table $TABLE already exists, skipping."
else
  aws dynamodb create-table \
    --table-name "$TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION"
fi

echo "Backend ready. Run: cd terraform && terraform init"
