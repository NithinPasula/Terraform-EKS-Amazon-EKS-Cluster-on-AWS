output "aws-eks-ip" {
  value = module.eks.cluster_endpoint
}