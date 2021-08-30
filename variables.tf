# Input variable definitions

variable "workspace" {
 type = string
}

variable "env" {
 type = string
}

variable "route53_hosted_zone_name" {
 type = string
}

variable "region" {
 type = string
}

variable "access_key" {
}

variable "secret_key" {
}

######################-VPC-RELATED-VARIABLES-#####################################################
variable "vpc_name" {
  description = "Name of VPC"
  type        = string
  default     = "example-vpc"
}



variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_azs" {
  description = "Availability zones for VPC"
  type        = list(string)
#  default     = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
}

variable "vpc_private_subnets" {
  description = "Private subnets for VPC"
  type        = list(string)
  default     = ["10.0.0.0/19", "10.0.32.0/19", "10.0.64.0/19"]
}

variable "vpc_public_subnets" {
  description = "Public subnets for VPC"
  type        = list(string)
  default     = ["10.0.128.0/19", "10.0.160.0/19", "10.0.192.0/19"]
}

variable "vpc_enable_nat_gateway" {
  description = "Enable NAT gateway for VPC"
  type        = bool
  default     = true
}

variable "vpc_enable_dns_hostnames" {
  description = "Enable dns hostnames for VPC"
  type        = bool
  default     = true
}

variable "vpc_enable_vpn_gateway" {
  description = "Disable vpn gateway for VPC"
  type        = bool
  default     = false
}

variable "vpc_single_nat_gateway" {
  description = "Enable single natgateway for VPC"
  type        = bool
  default     = true
}
####################################################################################################

data "http" "myip" {
  url = "https://ipecho.net/plain"
}

####################################-EC2-VM-DETAILS-################################################################
variable "instance_ami" {
  default     = "ami-06a0b4e3b7eb7a300"
}

#################################################-EKS-RELATED-VAriables-######################################################

variable "cluster_size_max" {
  default = "10"
}

variable "cluster_size_min" {
  default = "1"
}

variable "cluster_size_desired" {
  default = "4"
}

variable "eks_node_type" {

}


