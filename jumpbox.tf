resource "aws_security_group" "jumpbox-sg" {
  name = "sg_jumpbox_${var.workspace}_${var.env}"
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
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["1.186.0.0/16"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["1.186.37.148/32"]
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
    Name                                             = "sg-jumpbox-${var.env}-${var.workspace}"
    Workspace                                        = var.workspace
  }
}

######################################################################################

variable "jumpbox_instance_count" {
      default = 1
  }

variable "jumpbox_instance_type" {
  default = "t3.medium"
}

##########################################-IAM-ROLE-IAM-POLICY-IAM-PROFILE##################################

resource "aws_iam_role" "jumpbox-iam-role" {
  name               = "iam-role_${var.workspace}_${var.env}_jumpbox"
  path               = "/"
  assume_role_policy = file("./files/jumpbox-role.json")
}

resource "aws_iam_policy" "jumpbox-iam-_policy" {
  name = "iam-policy_${var.workspace}_${var.env}_jumpbox"
  description = "jumpbox policy to ec2 Volumes"
  policy = file("./files/jumpbox-policy.json")
}

resource "aws_iam_instance_profile" "jumpbox_iam_profile" {
  name = "iam_profile_${var.workspace}_${var.env}_jumpbox"
  role = aws_iam_role.jumpbox-iam-role.name
}

resource "aws_iam_policy_attachment" "jumpbox-iam-policy-attach" {
name       = "iam-policy-attachment-jumpbox"
roles      = [aws_iam_role.jumpbox-iam-role.name]
policy_arn = aws_iam_policy.jumpbox-iam-_policy.arn
}

#####################################################################################################


data "template_file" "jumpbox_user_data" {
  template = file("./templates/jumpbox_userdata.sh")

vars = {
    app_type         = "jumpbox"
    workspace = "${var.workspace}"
    env = "${var.env}"
    region = "${var.region}"
    route53_hosted_zone_name = "${var.route53_hosted_zone_name}"
  }
}


resource "aws_instance" "jumpbox_instance" {
  count                       = var.jumpbox_instance_count
  ami                         = var.instance_ami
  instance_type               = var.jumpbox_instance_type
  subnet_id                   = module.vpc.public_subnets[count.index % length(module.vpc.public_subnets)]
  key_name                    = aws_key_pair.keypair.id
  iam_instance_profile        = aws_iam_instance_profile.jumpbox_iam_profile.name
  associate_public_ip_address = true
  user_data = data.template_file.jumpbox_user_data.rendered
  security_groups             = [aws_security_group.jumpbox-sg.id]
  root_block_device {
      volume_type           = "gp2"
      volume_size           = "50"
  }

lifecycle {
    ignore_changes = [security_groups]
  }
tags = {
    Name = "${var.workspace}_${var.env}_jumpbox-${count.index + 1}"
    Workspace = var.workspace
    env = var.env
  }
depends_on = [aws_autoscaling_group.nfs-aws-asg]
}

########################################EXTRA-EBS-VOLUME-ATTACH-#############################
resource "aws_ebs_volume" "jumpbox-storage" {
  availability_zone = var.vpc_azs[count.index % length(var.vpc_azs)]
  size              = 100
  count             = var.jumpbox_instance_count
  type              = "gp2"
  tags = {
    Name = "ebs-${var.workspace}_${var.env}_jumpbox-${count.index + 1}"
    Workspace = var.workspace
    env = var.env
  }
}

resource "aws_volume_attachment" "jumpbox_vol_att" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.jumpbox-storage.*.id[count.index % length(aws_ebs_volume.jumpbox-storage.*.id)]
  instance_id = aws_instance.jumpbox_instance.*.id[count.index % length(aws_instance.jumpbox_instance.*.id)]
  count       = var.jumpbox_instance_count
}

