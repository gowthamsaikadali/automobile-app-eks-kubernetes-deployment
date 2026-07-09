# AutoForge — EKS Kubernetes Orchestration Project

A containerized Flask "automobile manufacturing dashboard" deployed to AWS
EKS with Terraform, Kubernetes manifests, Helm, HPA autoscaling, and a
GitHub Actions CI/CD pipeline using OIDC (no long-lived AWS keys).

Everything below is written for **Windows PowerShell**, assuming an **AWS
Free Trial account** with limited credits. All infrastructure defaults to
`t3.micro` and a minimum node count of 1.

---

## 0. What you're about to build

```
Internet
   |
   v
[ ALB / NLB Service ]  <-- Kubernetes Service (LoadBalancer) or Ingress
   |
   v
[ EKS Cluster ]
   |-- Namespace: dev
   |     |-- Deployment (autoforge-app, 1 replica, HPA 1-3)
   |     |-- ConfigMap (non-secret env vars)
   |     |-- Secret (DB password)
   |     |-- Service (ClusterIP + LoadBalancer)
   |
   |-- Namespace: prod
         |-- Deployment (autoforge-app, 2 replicas, HPA 2-5)
         |-- ConfigMap / Secret / Services (same pattern)

[ VPC ]  2 public + 2 private subnets, 1 NAT Gateway
[ ECR ]  Docker image registry
[ RDS ]  MySQL 8.0, private subnets only, reachable only from the EKS cluster SG
[ GitHub Actions ] --(OIDC, no keys)--> builds image -> pushes to ECR -> helm upgrade --install
```

**Cost note (read this first):** on a free-trial account, the EKS control
plane, NAT Gateway, and any LoadBalancer/ALB you create all cost money per
hour (they are not part of the "free tier" even though EC2 t3.micro often
is). Budget roughly $0.10/hr for the EKS control plane + a few cents/hr each for
the NAT Gateway, LoadBalancer, and the `db.t3.micro` RDS instance while
resources are running. **The teardown section below tells you exactly how
to delete everything, including RDS.** Don't leave this running overnight
unless you intend to.

---

## 1. Prerequisites (Windows)

Install these first, then open a **new** PowerShell window:

| Tool | Install command (using [Chocolatey](https://chocolatey.org/install)) |
|---|---|
| AWS CLI v2 | `choco install awscli` |
| Terraform | `choco install terraform` |
| kubectl | `choco install kubernetes-cli` |
| Helm | `choco install kubernetes-helm` |
| Docker Desktop | Download from https://www.docker.com/products/docker-desktop/ |
| Git | `choco install git` |
| GitHub CLI (optional) | `choco install gh` |

Verify everything is installed and your AWS credentials work:

```powershell
cd automobile-app-eks-kubernetes-deployment\scripts
.\00-prereqs-check.ps1
```

Configure your AWS CLI credentials if you haven't already:

```powershell
aws configure
# AWS Access Key ID, Secret Access Key, region (e.g. ap-south-1), output format (json)
```

> Use an IAM user with programmatic access, not your root account.

---

## 2. Project layout

```
automobile-app-eks-kubernetes-deployment/
├── app/                        # Flask app + Dockerfile
├── terraform/                  # VPC, EKS, ECR, IAM (root module + modules/)
├── k8s/                        # Raw Kubernetes manifests (dev/ and prod/)
├── helm/automobile-app/        # Helm chart used by the CI/CD pipeline
├── .github/workflows/deploy.yml  # GitHub Actions CI/CD pipeline
├── scripts/                    # PowerShell scripts, run in numeric order
└── docs/                       # Extra docs (ALB controller install, etc.)
```

---

## 3. Push the code to GitHub

```powershell
cd automobile-app-eks-kubernetes-deployment
git init
git add .
git commit -m "Initial commit: AutoForge EKS project"
git branch -M main
git remote add origin https://github.com/<your-username>/automobile-app-eks-kubernetes-deployment.git
git push -u origin main
```

---

## 4. Create the Terraform remote state backend (one-time)

This creates an S3 bucket + DynamoDB table so your Terraform state is stored
safely and locked during applies.

```powershell
cd scripts
.\01-bootstrap-backend.ps1 -BucketName "autoforge-tfstate-<yourname>-<random4digits>" -Region "ap-south-1"
```

Then open `terraform/versions.tf`, uncomment the `backend "s3" { ... }`
block, and replace the bucket name with the one you just created.

---

## 5. Configure your Terraform variables

```powershell
cd ..\terraform
Copy-Item terraform.tfvars.example terraform.tfvars
notepad terraform.tfvars
```

Set `github_oidc_repo` to `your-github-username/automobile-app-eks-kubernetes-deployment`
so GitHub Actions can assume the AWS IAM role via OIDC. Confirm
`node_instance_types = ["t3.micro"]` and `node_min_size = 1` are set (they
are, by default).

---

## 6. Deploy the infrastructure (VPC + EKS + ECR)

```powershell
cd ..\scripts
.\02-deploy-infra.ps1
```

This runs `terraform init`, `terraform plan`, shows you the plan, and asks
you to type `yes` to confirm before `terraform apply`. **EKS cluster
creation takes 10-15 minutes** — this is normal, AWS is provisioning the
control plane.

When it finishes, note the outputs — especially `ecr_repository_url` and
`github_actions_role_arn`. You'll need both.

---

## 7. Connect kubectl to the new cluster

```powershell
.\03-configure-kubectl.ps1 -Region "ap-south-1" -ClusterName "autoforge-eks"
```

You should see your node(s) listed:

```powershell
kubectl get nodes
```

---

## 8. Grant the GitHub Actions role permission to manage the cluster

IAM alone doesn't grant Kubernetes permissions — you need an EKS access entry:

```powershell
.\06-grant-cicd-cluster-access.ps1 -ClusterName "autoforge-eks" -RoleArn "<github_actions_role_arn from terraform output>"
```

Then add that role ARN as a GitHub secret:

```powershell
.\07-set-github-secrets-reminder.ps1 -RoleArn "<github_actions_role_arn>" -Repo "<your-username>/automobile-app-eks-kubernetes-deployment"
```

(If you don't have `gh` installed, it will print manual instructions — add
the secret `AWS_GITHUB_ACTIONS_ROLE_ARN` under
**Repo Settings → Secrets and variables → Actions**.)

---

## 9. First deploy — do it manually once (recommended before trusting CI/CD)

### Option A: Helm (recommended, matches the CI/CD pipeline)

```powershell
# Build and push the image
.\04-build-and-push-image.ps1 -Region "ap-south-1" -RepoName "autoforge-app" -Tag "v1"

# Deploy with Helm into the "dev" namespace
.\05-deploy-app-helm.ps1 -Environment "dev" -ImageRepo "<account-id>.dkr.ecr.ap-south-1.amazonaws.com/autoforge-app" -ImageTag "v1"
```

### Option B: Raw kubectl manifests

```powershell
.\04-build-and-push-image.ps1 -Region "ap-south-1" -RepoName "autoforge-app" -Tag "v1"
.\05b-deploy-app-raw-manifests.ps1 -Environment "dev" -Image "<account-id>.dkr.ecr.ap-south-1.amazonaws.com/autoforge-app:v1"
```

### Get the app URL

```powershell
kubectl get svc autoforge-lb -n dev
```

Wait 1-3 minutes for the `EXTERNAL-IP`/hostname column to populate, then
open `http://<that-hostname>` in your browser.

### Watch it self-heal and autoscale

```powershell
# Self-healing: delete a pod, watch Kubernetes recreate it
kubectl get pods -n dev
kubectl delete pod <pod-name> -n dev
kubectl get pods -n dev -w

# Autoscaling: watch the HPA (won't scale up without real load, this just
# confirms it's reading metrics)
kubectl get hpa -n dev -w
```

> If `kubectl get hpa` shows `<unknown>` under TARGETS, the Metrics Server
> isn't installed. Install it with:
> `kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml`

---

## 10. Let the CI/CD pipeline take over

From now on, any push to `main` triggers `.github/workflows/deploy.yml`,
which builds the image, pushes it to ECR, and runs `helm upgrade --install`
against the `dev` namespace automatically. To deploy to `prod` instead, run
the workflow manually from the GitHub Actions tab and choose `prod` from the
dropdown (this uses `workflow_dispatch`).

---

## 11. Two-tier setup: wire up the real MySQL (RDS) database

See docs/two-tier-mysql-setup.md for the full walkthrough (provisioning RDS,
pointing the app at it, seeding the schema, and verifying connectivity).

## 12. (Optional) Ingress via AWS Load Balancer Controller

The `LoadBalancer` Service in step 9 is enough to reach the app. If you
specifically want to exercise the `Ingress` resource with an ALB, see
`docs/aws-load-balancer-controller.md` for the extra one-time setup.

---

## 13. Tear everything down (IMPORTANT — do this when you're done)

```powershell
cd scripts
.\99-destroy-all.ps1
```

This uninstalls the Helm release (removing the LoadBalancer first, so
Terraform doesn't get stuck on a dangling ELB), then runs
`terraform destroy` to remove the EKS cluster, NAT Gateway, VPC, and ECR
repository. Afterwards, **manually check the AWS Console** for:
EC2 → Load Balancers, EC2 → NAT Gateways/Elastic IPs, EKS → Clusters, ECR →
Repositories, VPC → Your VPCs — confirm nothing is left running.

If you also want to remove the Terraform state backend:

```powershell
aws s3 rb s3://<your-bucket-name> --force
aws dynamodb delete-table --table-name autoforge-tf-lock
```

---

## Troubleshooting quick reference

| Symptom | Likely cause / fix |
|---|---|
| `terraform apply` fails with ENI/IP limit errors | `t3.micro` supports a limited number of pod IPs via the VPC CNI. Keep replica counts low (1-2) per node, or use a larger instance type if you have credits to spare. |
| Pods stuck in `Pending` | Check `kubectl describe pod <name> -n dev` — usually insufficient CPU/memory on the t3.micro node, or no nodes joined yet. |
| `ImagePullBackOff` | Image URI in the Deployment/Helm values doesn't match the ECR repo, or the node IAM role is missing `AmazonEC2ContainerRegistryReadOnly` (already attached by Terraform). |
| GitHub Actions fails on `aws eks update-kubeconfig` with access denied | You skipped step 8 (`06-grant-cicd-cluster-access.ps1`) — the IAM role needs an EKS access entry, not just IAM trust. |
| `kubectl` gives "Unauthorized" after a while | Your token expired; re-run `.\03-configure-kubectl.ps1`. |
| LoadBalancer `EXTERNAL-IP` stuck on `<pending>` | Give it 2-3 minutes; if it persists, check the node/public subnet tags (`kubernetes.io/role/elb`) — already set by the Terraform VPC module. |

---

## What satisfies each objective

- **Provision an EKS cluster via Terraform** → `terraform/` (VPC, EKS, ECR, IAM modules)
- **Deployment, Service (ClusterIP + LoadBalancer), Ingress** → `k8s/dev/*.yaml`, `k8s/prod/*.yaml`, and Helm equivalents in `helm/automobile-app/templates/`
- **ConfigMaps + Secrets** → `configmap.yaml` / `secret.yaml` in both `k8s/` and Helm templates
- **HPA on CPU/memory** → `hpa.yaml` (CPU 70%, memory 80%, dev: 1-3 replicas, prod: 2-5)
- **Namespaces (dev/prod)** → `k8s/namespaces.yaml`, and `--namespace` / `values-dev.yaml` / `values-prod.yaml` in Helm
- **CI/CD via kubectl apply or Helm** → `.github/workflows/deploy.yml` uses `helm upgrade --install`, with raw-manifest scripts provided as an alternative
- **Two-tier architecture (Flask + MySQL)** → `terraform/modules/rds/` provisions RDS MySQL; `app/db.py` + `app/seed.py` handle the data layer; see `docs/two-tier-mysql-setup.md`
