# AutoForge-K8s — fully automated EKS deployment

Runs a containerized app at scale with self-healing and autoscaling.
Everything except two one-time bootstrap steps is now automated via Terraform + GitHub Actions.

## The only two manual steps, ever

1. `./bootstrap.sh` — creates the S3 state bucket + DynamoDB lock table
   (has to exist before Terraform can store state in it — chicken and egg).
2. The first `terraform apply` — someone has to press go once. After this,
   the `terraform` job in the GitHub Actions workflow re-runs it automatically
   whenever files under `terraform/` change.

## What Terraform now owns (previously manual)

| Used to be | Now |
|---|---|
| `aws ecr create-repository` | `terraform/ecr.tf` |
| Manual OIDC provider + IAM role creation | `terraform/oidc.tf` |
| `kubectl edit configmap aws-auth` | `access_entries` block in `terraform/eks.tf` |
| `kubectl apply 00-namespaces.yaml`, `01-configmap.yaml`, `kubectl create secret` | `terraform/k8s-resources.tf` |
| `kubectl apply metrics-server` | `terraform/metrics-server.tf` |
| Static `AWS_ACCESS_KEY_ID`/`SECRET` in GitHub secrets | OIDC federation — no long-lived keys anywhere |

The `k8s-manifests/` folder stays in the repo as reference — worth reading
once to understand what each object does — but you don't `kubectl apply`
any of it anymore. Terraform and Helm own the real deployment.

## First-time setup

```bash
./bootstrap.sh
cd terraform
cp terraform.tfvars.example terraform.tfvars   # fill in real DB creds, gitignored
terraform init
terraform apply
terraform output github_actions_role_arn       # paste into deploy.yaml's GHA_ROLE_ARN
```

Then in GitHub: Settings → Secrets → add `DEV_DB_USERNAME`, `DEV_DB_PASSWORD`,
`PROD_DB_USERNAME`, `PROD_DB_PASSWORD` (used by both Terraform and Helm now).
Settings → Environments → create `prod` with a required reviewer.

## Day to day

```bash
git push origin dev    # app change → build, test, push, deploy to dev — fully automatic
git push origin main   # merge → build → pauses for your approval → deploys to prod
```
Changing something under `terraform/`? Push it — the `terraform` job applies it
automatically, no local `terraform apply` needed again.

## Cost note

`terraform destroy` when you're done for the day — EKS + NAT gateway bill
hourly regardless of load. `terraform apply` brings everything back,
including namespaces/secrets/metrics-server, in ~15 minutes.
