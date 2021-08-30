resource "aws_security_group" "eks-sg" {
  name = "sg_eks_${var.workspace}_${var.env}"
  vpc_id = module.vpc.vpc_id
  ingress {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }

   ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

 egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
tags = {
    Owner                                            = "Devops dmlabs"
    Environment                                      = var.env
    Name                                             = "sg-eks-${var.env}-${var.workspace}"
    Workspace                                        = var.workspace
  }
}


resource "aws_security_group" "worker-node-sg" {
  name = "sg_worker-node_${var.workspace}_${var.env}"
  vpc_id = module.vpc.vpc_id
  ingress {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }

   ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }


 egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
tags = {
    Owner                                            = "Devops dmlabs"
    Environment                                      = var.env
    Name                                             = "sg-eks-${var.env}-${var.workspace}"
    Workspace                                        = var.workspace
  }
}



##########################################-IAM-ROLE-IAM-POLICY-IAM-PROFILE##################################

resource "aws_iam_role" "eks-iam-role" {
  name               = "iam-role_${var.workspace}_${var.env}_eks"
  path               = "/"
  assume_role_policy = file("./files/eks-role.json")
}

resource "aws_iam_policy" "eks-iam-_policy" {
  name = "iam-policy_${var.workspace}_${var.env}_eks"
  description = "eks policy to ec2 Volumes"
  policy = file("./files/eks-policy.json")
}

resource "aws_iam_instance_profile" "eks_iam_profile" {
  name = "iam_profile_${var.workspace}_${var.env}_eks"
  role = aws_iam_role.eks-iam-role.name
}

resource "aws_iam_policy_attachment" "eks-iam-policy-attach" {
name       = "iam-policy-attachment-eks"
roles      = [aws_iam_role.eks-iam-role.name]
policy_arn = aws_iam_policy.eks-iam-_policy.arn
}


#############################################-WORKER_NODEASG_Launch-TEMPLATE_CEATION_##################

data "template_file" "eks_user_data" {
  template = file("./templates/eks_userdata.sh.tpl")

vars = {
    app_type         = "eks"
    route53_hosted_zone_name = "${var.route53_hosted_zone_name}"
  }
}

#############################################################

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  #load_config_file       = false
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "17.1.0"
  cluster_version                      = "1.19"
  cluster_name                         = "${var.workspace}-${var.env}-cluster"
  subnets                              = "${module.vpc.private_subnets}"
  tags                                 = "${local.common_tags}"
  vpc_id                               = module.vpc.vpc_id
  #worker_additional_security_group_ids = [aws_security_group.worker-node-sg.id]
  map_users                            = local.map_users
  manage_aws_auth                      = true
  #write_aws_auth_config                = true
  write_kubeconfig                     = true
  kubeconfig_aws_authenticator_command = "aws"
  kubeconfig_aws_authenticator_command_args = ["eks", "get-token", "--cluster-name", "${var.workspace}-${var.env}-cluster"]
  manage_worker_iam_resources          = false
  workers_group_defaults               = "${local.workers_group_defaults}"
  worker_groups_launch_template        = ["${local.workers_group_defaults}"]
  map_roles                            = local.map_roles
  cluster_create_security_group        = true
  cluster_enabled_log_types            = ["scheduler","controllerManager"]
  worker_security_group_id             = aws_security_group.worker-node-sg.id
  cluster_security_group_id            = aws_security_group.eks-sg.id
  cluster_create_timeout               = "30m"
  worker_create_security_group         = "false"

depends_on = [aws_iam_instance_profile.eks_iam_profile, aws_iam_instance_profile.jumpbox_iam_profile]
  }
