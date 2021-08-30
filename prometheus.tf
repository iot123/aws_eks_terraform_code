resource "aws_security_group" "prometheus-sg" {
  name = "sg_prometheus_${var.workspace}_${var.env}"
  vpc_id = module.vpc.vpc_id
  ingress {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }
    ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }

   ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["1.186.77.148/32"]
  }

 ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["1.186.37.148/32"]
  }

  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 9300
    to_port     = 9300
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
    Name                                             = "sg-prometheus-${var.env}-${var.workspace}"
    Workspace                                        = var.workspace
  }
}

##########################################-IAM-ROLE-IAM-POLICY-IAM-PROFILE##################################

resource "aws_iam_role" "prometheus-iam-role" {
  name               = "iam-role_${var.workspace}_${var.env}_prometheus"
  path               = "/"
  assume_role_policy = file("./files/prometheus-role.json")
}

resource "aws_iam_policy" "prometheus-iam-_policy" {
  name = "iam-policy_${var.workspace}_${var.env}_prometheus"
  description = "prometheus policy to ec2 Volumes"
  policy = file("./files/prometheus-policy.json")
}

resource "aws_iam_instance_profile" "prometheus_iam_profile" {
  name = "iam_profile_${var.workspace}_${var.env}_prometheus"
  role = aws_iam_role.prometheus-iam-role.name
}

resource "aws_iam_policy_attachment" "prometheus-iam-policy-attach" {
name       = "iam-policy-attachment-prometheus"
roles      = [aws_iam_role.prometheus-iam-role.name]
policy_arn = aws_iam_policy.prometheus-iam-_policy.arn
}


######################################################################################

variable "prometheus_instance_count" {
      default = 1
  }

variable "prometheus_instance_type" {
  default = "t3.medium"
}

data "template_file" "prometheus_user_data" {
  template = file("./templates/prometheus.sh")

vars = {
    app_type         = "prometheus"
    workspace = "${var.workspace}"
    env = "${var.env}"
    region = "${var.region}"
  }
}

resource "aws_instance" "prometheus_instance" {
  count                       = var.prometheus_instance_count
  ami                         = var.instance_ami
  instance_type               = var.prometheus_instance_type
  subnet_id                   = module.vpc.public_subnets[count.index % length(module.vpc.public_subnets)]
  key_name                    = aws_key_pair.keypair.id
  iam_instance_profile        = aws_iam_instance_profile.prometheus_iam_profile.name
  associate_public_ip_address = true
  user_data = data.template_file.prometheus_user_data.rendered
  security_groups             = [aws_security_group.prometheus-sg.id]
  root_block_device {
      volume_type           = "gp2"
      volume_size           = "50"
  }

lifecycle {
    ignore_changes = [security_groups]
  }
tags = {
    Name = "${var.workspace}_${var.env}_prometheus-${count.index + 1}"
    Workspace = var.workspace
    env = var.env
  }
}

########################################EXTRA-EBS-VOLUME-ATTACH-#############################
resource "aws_ebs_volume" "prometheus-storage" {
  availability_zone = var.vpc_azs[count.index % length(var.vpc_azs)]
  size              = 150
  count             = var.prometheus_instance_count
  type              = "gp2"
  tags = {
    Name = "ebs-${var.workspace}_${var.env}_prometheus-${count.index + 1}"
    Workspace = var.workspace
    env = var.env
  }
}

resource "aws_volume_attachment" "prometheus_vol_att" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.prometheus-storage.*.id[count.index % length(aws_ebs_volume.prometheus-storage.*.id)]
  instance_id = aws_instance.prometheus_instance.*.id[count.index % length(aws_instance.prometheus_instance.*.id)]
  count       = var.prometheus_instance_count
}

