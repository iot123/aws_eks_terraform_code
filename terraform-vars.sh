#!/bin/bash
touch terraform.auto.tfvars
echo "workspace = \"$1\"" > terraform.auto.tfvars
echo "env = \"$2\"" >> terraform.auto.tfvars
echo "route53_hosted_zone_name = \"$3\"" >> terraform.auto.tfvars
echo "region = \"$4\"" >> terraform.auto.tfvars
echo "instance_ami = \"$5\"" >> terraform.auto.tfvars
echo "vpc_azs = [\"$4a\", \"$4b\", \"$4c\"]" >> terraform.auto.tfvars
echo "eks_node_type = \"$6\"" >> terraform.auto.tfvars
echo "access_key = \"$7\"" >> terraform.auto.tfvars
echo "secret_key = \"$8\"" >> terraform.auto.tfvars

