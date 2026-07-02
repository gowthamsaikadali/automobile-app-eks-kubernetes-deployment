# The official EKS module handles the control plane, IAM roles, OIDC provider
# (needed for IRSA — IAM Roles for Service Accounts, e.g. for the ALB controller),
# and the managed node group in one resource. This is what most production
# teams use rather than writing aws_eks_cluster by hand.

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true   # kubectl from your laptop without a bastion

  # Required so the ALB Ingress Controller can assume an IAM role via a
  # Kubernetes service account (IRSA) instead of node-wide IAM permissions.
  enable_irsa = true

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"

      desired_size = var.node_desired_size
      min_size     = var.node_min_size
      max_size     = var.node_max_size

      labels = {
        role = "general"
      }
    }
  }

  # Lets your IAM user/role (whoever runs terraform apply) get cluster-admin
  # via `aws eks update-kubeconfig` without extra aws-auth ConfigMap wrangling.
  enable_cluster_creator_admin_permissions = true

  tags = {
    Project = "autoforge-k8s"
  }
}

# --- AWS Load Balancer Controller ---
# This is the piece that turns a Kubernetes Ingress resource into a real
# AWS Application Load Balancer. Without it, `kind: Ingress` manifests
# just sit there doing nothing on EKS.

resource "aws_iam_role" "alb_controller" {
  name = "${var.cluster_name}-alb-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(module.eks.oidc_provider, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess" # tighten in real prod; fine for this build
}

resource "kubernetes_service_account" "alb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller.arn
    }
  }
  depends_on = [module.eks]
}

resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  depends_on = [kubernetes_service_account.alb_controller]
}
