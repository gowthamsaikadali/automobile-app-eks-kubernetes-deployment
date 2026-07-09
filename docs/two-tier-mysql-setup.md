# Two-Tier Setup: Wiring Up RDS MySQL

The app is a genuine two-tier application: Flask (app tier) + RDS MySQL
(data tier), matching the architecture of
[Automobile-Manufacturing-Application](https://github.com/gowthamsaikadali/Automobile-Manufacturing-Application),
just running on EKS instead of a single EC2 instance. Terraform provisions
the RDS instance as part of the normal `terraform apply` (via the `rds`
module in `terraform/modules/rds`) — these steps connect the app to it.

All commands are PowerShell, run from the project root unless noted.

---

## 1. Set a real DB password

```powershell
cd terraform
notepad terraform.tfvars
```

Set `db_password` to a real strong password (not the example placeholder).
Then apply (or re-apply if you already ran `terraform apply` once without
setting this):

```powershell
terraform plan -out=tfplan
terraform apply tfplan
```

RDS provisioning takes **5-10 minutes**. Once it finishes:

```powershell
terraform output db_address
```

Note this value down — it's the RDS endpoint (no port).

---

## 2. Point the app at RDS

This creates/updates the ConfigMap + Secret in your target namespace
automatically — no manual YAML editing or copy-paste mistakes:

```powershell
cd ..\scripts
.\08-configure-database.ps1 -Environment "dev" -DbPassword "<the same password you put in terraform.tfvars>"
```

---

## 3. Rebuild and push the image

The app code now includes `db.py` (MySQL connection helper), an updated
`app.py` (real CRUD against MySQL instead of an in-memory list), and
`seed.py` (schema + starter data):

```powershell
.\04-build-and-push-image.ps1 -Region "ap-south-1" -RepoName "autoforge-app" -Tag "v2"
```

---

## 4. Create the schema and seed starter data

```powershell
.\09-seed-database.ps1 -Environment "dev" -Image "<account-id>.dkr.ecr.ap-south-1.amazonaws.com/autoforge-app:v2"
```

This runs `seed.py` as a one-off Kubernetes Job (defined in
`k8s/dev/seed-job.yaml`). It's safe to re-run — the script skips inserting
starter rows if the table already has data. Watch the printed logs to
confirm the `vehicles` table was created and seeded.

---

## 5. Deploy the updated app and restart

```powershell
.\05-deploy-app-helm.ps1 -Environment "dev" -ImageRepo "<account-id>.dkr.ecr.ap-south-1.amazonaws.com/autoforge-app" -ImageTag "v2"
kubectl rollout restart deployment/autoforge-app -n dev
```

---

## 6. Verify

```powershell
kubectl get svc autoforge-lb -n dev
```

Open the LoadBalancer hostname in your browser — you should now see real
rows from MySQL, plus a working "Add Vehicle" form and delete buttons that
persist to the database. Double-check connectivity directly:

```powershell
kubectl exec -n dev deploy/autoforge-app -- curl -s http://localhost:5000/api/info
```

`db_connected` should be `true`.

---

## Design notes

**Shared RDS instance across dev/prod.** Both namespaces currently point at
the *same* RDS instance and `db_name` for simplicity and cost control on a
free-trial account — RDS is the single most expensive piece of this whole
stack, and running two instances (one per environment) roughly doubles that
cost. If you want fully isolated prod data instead, either:
- create a second logical database on the same instance
  (`CREATE DATABASE autoforge_prod;` via a MySQL client) and point the
  `prod` ConfigMap's `DB_NAME` at it, or
- provision a second `rds` module instance for prod if you have the budget.

**Security group scoping.** The RDS security group (in
`terraform/modules/rds/main.tf`) only allows inbound MySQL (port 3306)
traffic from the EKS cluster's shared security group
(`eks_cluster_security_group_id`) — the DB is not publicly accessible from
the internet. This matches how a real two-tier app should be locked down;
don't widen this to `0.0.0.0/0` even for troubleshooting.

**Liveness vs. readiness split.** `/healthz` (liveness) never touches the
database — only `/readyz` does. This means a temporarily slow or
unreachable database marks the pod "not ready" (so it stops receiving
traffic) without Kubernetes killing and restarting a perfectly healthy
process, which would otherwise cause a crash-loop unrelated to the actual
problem.

---

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `/api/info` shows `db_connected: false` | Check the security group allows the EKS cluster SG on port 3306; check `DB_HOST`/`DB_PASSWORD` match what Terraform actually created (`terraform output db_address`, and the password you passed to `08-configure-database.ps1`). |
| Seed Job stuck / `CrashLoopBackOff` | `kubectl logs job/autoforge-seed -n dev` — usually a connection timeout, meaning the security group or `DB_HOST` is wrong. |
| `Access denied for user` in seed logs | The Secret's `DB_PASSWORD` doesn't match `terraform.tfvars`' `db_password`. Re-run step 2 with the correct value. |
| RDS takes forever to appear in `terraform apply` | Normal — RDS provisioning genuinely takes 5-10 minutes, longer than most other resources in this stack. |
| Website loads but shows "No vehicles yet" | The seed Job hasn't run yet, or ran before the ConfigMap/Secret were correctly pointed at RDS. Re-run steps 2 and 4 in order. |
