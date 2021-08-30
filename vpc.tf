module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.21.0"
  name = "vpc-${var.env}-${var.workspace}"
  cidr = var.vpc_cidr
  azs             = var.vpc_azs
  private_subnets = var.vpc_private_subnets
  public_subnets  = var.vpc_public_subnets
  enable_nat_gateway = var.vpc_enable_nat_gateway
  enable_dns_hostnames = var.vpc_enable_dns_hostnames
  enable_vpn_gateway   = var.vpc_enable_vpn_gateway
  single_nat_gateway   = var.vpc_single_nat_gateway
  tags = {
    Owner                                            = "Devops dmlabs"
    Environment                                      = var.env
    Name                                             = "vpc-${var.env}-${var.workspace}"
    Workspace                                        = var.workspace
  }
}
