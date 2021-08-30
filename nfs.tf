resource "aws_security_group" "nfs-sg" {
  name = "sg_nfs_${var.workspace}_${var.env}"
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
    Name                                             = "sg-nfs-${var.env}-${var.workspace}"
    Workspace                                        = var.workspace
  }
}

######################################################################################

variable "nfs_instance_count" {
      default = 1
  }

variable "nfs_instance_type" {
  default = "t3.medium"
}

variable "nfs_cluster_size_max" {
  default = "1"
}

variable "nfs_cluster_size_min" {
  default = "1"
}

variable "nfs_cluster_size_desired" {
  default = "1"
}



##########################################-IAM-ROLE-IAM-POLICY-IAM-PROFILE##################################

resource "aws_iam_role" "nfs-iam-role" {
  name               = "iam-role_${var.workspace}_${var.env}_nfs"
  path               = "/"
  assume_role_policy = file("./files/nfs-role.json")
}

resource "aws_iam_policy" "nfs-iam-_policy" {
  name = "iam-policy_${var.workspace}_${var.env}_nfs"
  description = "nfs policy to ec2 Volumes"
  policy = file("./files/nfs-policy.json")
}

resource "aws_iam_instance_profile" "nfs_iam_profile" {
  name = "iam_profile_${var.workspace}_${var.env}_nfs"
  role = aws_iam_role.nfs-iam-role.name
}

resource "aws_iam_policy_attachment" "nfs-iam-policy-attach" {
name       = "iam-policy-attachment-nfs"
roles      = [aws_iam_role.nfs-iam-role.name]
policy_arn = aws_iam_policy.nfs-iam-_policy.arn
}


########################################EXTRA-EBS-VOLUME-ATTACH-#############################
resource "aws_ebs_volume" "nfs-storage" {
  availability_zone = element(var.vpc_azs, 0)
  size              = 300
  type              = "gp2"
  tags = {
    Name = "ebs-${var.workspace}_nfs"
    Workspace = var.workspace
    env = var.env
  }
}

#############################################-KAFKA-ASG_Launch-TEMPLATE_CEATION_##################

data "template_file" "nfs_user_data" {
  template = file("./templates/nfs_userdata.sh.tpl")

vars = {
    app_type         = "nfs"
    nfs_ebs_volume      = aws_ebs_volume.nfs-storage.id
    aws_region      = var.region
    vpc_cidr = var.vpc_cidr 
  }
}


resource "aws_launch_configuration" "nfs-aws-lc" {
  name_prefix          = "lc-${var.workspace}-${var.env}-nfs"
  image_id             = var.instance_ami
  instance_type        = var.nfs_instance_type
  security_groups      = [aws_security_group.nfs-sg.id]
  user_data            = data.template_file.nfs_user_data.rendered
  key_name             = aws_key_pair.keypair.id
  iam_instance_profile = aws_iam_instance_profile.nfs_iam_profile.name
  root_block_device {
    volume_size           = 100
    volume_type           = "gp2"
    delete_on_termination = "true"
  }

  lifecycle {
    create_before_destroy = true
  }
  depends_on = [aws_ebs_volume.nfs-storage]
}


resource "aws_autoscaling_group" "nfs-aws-asg" {
  name_prefix          = "nfs-server-asg-${var.workspace}-${var.env}"
  desired_capacity     = var.nfs_cluster_size_desired
  max_size             = var.nfs_cluster_size_max
  min_size             = var.nfs_cluster_size_min
  force_delete         = true
  launch_configuration = aws_launch_configuration.nfs-aws-lc.name
  vpc_zone_identifier = [module.vpc.private_subnets[0]]
  tags = [
    {
    key                 = "Name"
    value               = "nfs-server-asg-${var.workspace}-${var.env}"
    propagate_at_launch = "true"
    },
    {
      key                 = "Workspace"
      value               = var.workspace
      propagate_at_launch = "true"
    },
    {
      key                 = "env"
      value               = var.env
      propagate_at_launch = "true"
    }
  ]
depends_on = [aws_launch_configuration.nfs-aws-lc]
}



#########################################################-ROUTE53-DETAILS-#####################################
data "aws_instances" "get_nfs_ip" {
  instance_tags = {
    Name = "nfs-server-asg-${var.workspace}-${var.env}"
}
  instance_state_names = ["running"]
  depends_on = [aws_autoscaling_group.nfs-aws-asg]
}

resource "aws_route53_record" "nfs_route" {
  zone_id = aws_route53_zone.private.id
  name    = "nfs.${var.route53_hosted_zone_name}"
  type    = "A"
  ttl     = "300"
  records = [element(data.aws_instances.get_nfs_ip.private_ips, 0)]
}
