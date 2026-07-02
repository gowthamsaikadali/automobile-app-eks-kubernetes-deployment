# A minimal, correct VPC for EKS: 2 public subnets (for the ALB) and
# 2 private subnets (for worker nodes) across 2 AZs, with a single NAT
# gateway so private nodes can still pull images / reach AWS APIs.
#
# We use the community "vpc" module instead of hand-rolling one — this
# is the same module the official EKS docs recommend, and it correctly
# sets the tags EKS and the ALB controller expect (kubernetes.io/role/elb etc).

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = [for i, az in var.azs : cidrsubnet(var.vpc_cidr, 8, i)]
  public_subnets  = [for i, az in var.azs : cidrsubnet(var.vpc_cidr, 8, i + 10)]

  enable_nat_gateway   = true
  single_nat_gateway   = true   # one NAT, not one per AZ — cheaper, fine for dev/prod demo scale
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${var.cluster_name}"      = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                = "1"
    "kubernetes.io/cluster/${var.cluster_name}"      = "shared"
  }
}
