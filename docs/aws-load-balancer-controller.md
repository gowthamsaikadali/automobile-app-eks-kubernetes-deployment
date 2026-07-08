# Installing the AWS Load Balancer Controller (optional, needed for Ingress)

The `ingress.yaml` manifests use `kubernetes.io/ingress.class: alb`, which
requires the **AWS Load Balancer Controller** to be running on the cluster.
This is optional — if you don't want to install it, just skip Ingress and use
the `autoforge-lb` LoadBalancer Service instead (works out of the box, no
extra controller needed). This is the recommended path for a quick, low-cost
free-trial demo.

If you do want to try the Ingress/ALB path:

```powershell
# 1. Create an IAM policy for the controller
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.8.1/docs/install/iam_policy.json
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam-policy.json

# 2. Create an IRSA service account bound to that policy (requires eksctl)
eksctl create iamserviceaccount `
  --cluster=autoforge-eks `
  --namespace=kube-system `
  --name=aws-load-balancer-controller `
  --attach-policy-arn=arn:aws:iam::<ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy `
  --approve

# 3. Install the controller with Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller `
  -n kube-system `
  --set clusterName=autoforge-eks `
  --set serviceAccount.create=false `
  --set serviceAccount.name=aws-load-balancer-controller
```

**Free-trial note:** an ALB itself costs money per hour it runs, same as the
NLB created by the LoadBalancer Service. Whichever path you pick, remember to
delete it (`helm uninstall`, `kubectl delete ingress/svc`) before running
`terraform destroy`, and don't leave it running longer than needed.
