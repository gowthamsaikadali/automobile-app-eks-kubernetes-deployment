# AutoForge-K8s — production-style Kubernetes on EKS

Runs a containerized app at scale with self-healing and autoscaling.

## What's in here

| Path | Purpose |
|---|---|
| `terraform/` | Provisions VPC + EKS cluster + node group + ALB controller |
| `k8s-manifests/` | Raw, standalone manifests — read these to understand each piece |
| `helm/autoforge/` | Templated version of the same manifests, parameterized for dev/prod |
| `.github/workflows/deploy.yaml` | CI/CD: build → test → push to ECR → helm upgrade |

## Build order

1. `terraform/` — stand up the cluster (~15 min, one-time)
2. `k8s-manifests/00` through `07` — apply by hand once, to see and understand
   every object before automating it
3. `helm/autoforge/` — same app, now templated for repeatable dev/prod deploys
4. `.github/workflows/deploy.yaml` — push to `dev` or `main` and let the
   pipeline do steps 2-3 for you going forward

## GitHub Actions secrets you need to set

Settings → Secrets and variables → Actions:
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
- `DEV_DB_USERNAME`, `DEV_DB_PASSWORD`
- `PROD_DB_USERNAME`, `PROD_DB_PASSWORD`

Settings → Environments → create `prod` with a required reviewer, so
production deploys need manual sign-off.

## Cost note

EKS control plane is billed per hour regardless of load, plus the NAT
gateway and 2x t3.medium nodes. Run `terraform destroy` when you're not
actively working on this to avoid burning credits between sessions —
`terraform apply` brings it back in ~15 minutes.
