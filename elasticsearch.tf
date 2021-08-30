resource "aws_security_group" "elasticsearch-sg" {
  name = "sg_elasticsearch_${var.workspace}_${var.env}"
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
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
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
    Name                                             = "sg-elasticsearch-${var.env}-${var.workspace}"
    Workspace                                        = var.workspace
  }
}

######################################################################################

variable "elasticsearch_instance_count" {
      default = 3
  }

variable "elasticsearch_instance_type" {
  default = "t3.medium"
}


resource "aws_instance" "elasticsearch_instance" {
  count                       = var.elasticsearch_instance_count
  ami                         = var.instance_ami
  instance_type               = var.elasticsearch_instance_type
  subnet_id                   = module.vpc.private_subnets[count.index % length(module.vpc.private_subnets)]
  key_name                    = aws_key_pair.keypair.id
  associate_public_ip_address = false
  user_data = file("./templates/volume-attach.sh")
  security_groups             = [aws_security_group.elasticsearch-sg.id]
  root_block_device {
      volume_type           = "gp2"
      volume_size           = "50"
  }

lifecycle {
    ignore_changes = [security_groups]
  }
tags = {
    Name = "${var.workspace}_${var.env}_elasticsearch-${count.index + 1}"
    Workspace = var.workspace
    env = var.env
  }
}

########################################EXTRA-EBS-VOLUME-ATTACH-#############################
resource "aws_ebs_volume" "elasticsearch-storage" {
  availability_zone = var.vpc_azs[count.index % length(var.vpc_azs)]
  size              = 100
  count             = var.elasticsearch_instance_count
  type              = "gp2"
  tags = {
    Name = "ebs-${var.workspace}_${var.env}_elasticsearch-${count.index + 1}"
    Workspace = var.workspace
    env = var.env
  }
}

resource "aws_volume_attachment" "elasticsearch_vol_att" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.elasticsearch-storage.*.id[count.index % length(aws_ebs_volume.elasticsearch-storage.*.id)]
  instance_id = aws_instance.elasticsearch_instance.*.id[count.index % length(aws_instance.elasticsearch_instance.*.id)]
  count       = var.elasticsearch_instance_count
}


########################################-ROUTE53-ENTRY-ADDITION_###########################

data "aws_instances" "get_elasticsearch_ip" {
  count = var.elasticsearch_instance_count
  instance_tags = {
    Name = "${var.workspace}_${var.env}_elasticsearch-${count.index + 1}"
}
  instance_state_names = ["running"]
  depends_on = [aws_instance.elasticsearch_instance]
}

resource "aws_route53_record" "elasticsearch_route" {
  count = var.elasticsearch_instance_count
  zone_id = aws_route53_zone.private.id
  name    = "elasticsearch${count.index + 1}.${var.route53_hosted_zone_name}"
  type    = "A"
  ttl     = "300"
  records = [element(data.aws_instances.get_elasticsearch_ip[count.index].private_ips, 0)]
}

