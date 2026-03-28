module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "${local.name}-eks-cluster"
  kubernetes_version = "1.33"

  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  vpc_id                   = module.vpc.default_vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  eks_managed_node_groups = {
    bankapp-ng = {
      min_size     = 2
      max_size     = 3
      desired_size = 2

      instance_types = ["t2.medium"]
      capacity_type  = "SPOT"

      tags = {
        ExtraTag = "MyCluster"
      }
    }
  }

  tags = local.tags
}
