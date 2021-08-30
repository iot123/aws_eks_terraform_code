resource "aws_route53_zone" "private" {
  name = var.route53_hosted_zone_name

 vpc {
    vpc_id = module.vpc.vpc_id
  }

}

