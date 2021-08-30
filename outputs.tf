# Output variable definitions

output "vpc_public_subnets" {
  description = "IDs of the VPC's public subnets"
  value       = module.vpc.public_subnets
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_private_subnets" {
  value = module.vpc.private_subnets
}

output "key_name" {
  value = aws_key_pair.keypair.id
}

output "kubeconfig" {
  value = module.eks.kubeconfig
}

