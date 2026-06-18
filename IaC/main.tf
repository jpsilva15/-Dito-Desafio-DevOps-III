module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = local.name
  kubernetes_version = "1.33"

  # Acesso público ao endpoint da API (restrinja em produção)
  endpoint_public_access = true

  # Adiciona quem está rodando o Terraform como admin via access entry
  enable_cluster_creator_admin_permissions = true

  addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
    eks-pod-identity-agent = {
      before_compute = true
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    spot = {
      ami_type = "AL2023_x86_64_STANDARD"

      instance_types = var.eks_node_instance_types

      capacity_type = "SPOT"

      min_size     = var.eks_node_min_size
      max_size     = var.eks_node_max_size
      desired_size = var.eks_node_desired_size

      labels = {
        "capacity-type" = "spot"
      }
    }
  }

  tags = local.tags
}