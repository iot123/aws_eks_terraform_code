locals { 
  workers_group_defaults = {
    name                 = "worker_nodes_${var.workspace}_${var.env}"
    instance_type        = var.eks_node_type
    iam_instance_profile_name = "${aws_iam_instance_profile.eks_iam_profile.name}"
    asg_desired_capacity = var.cluster_size_desired
    asg_max_size         = var.cluster_size_max
    asg_min_size         = var.cluster_size_min
    key_name             = aws_key_pair.keypair.id
    enable_monitoring    = true
    # Move to template 
    additional_userdata  = data.template_file.eks_user_data.rendered
    tags = [
            {
              key                 = "Name"
              value               = "k8s_${var.workspace}_${var.env}_worker_nodes" 
              propagate_at_launch = true
            },
            {
              key                 = "kubernetes.io/cluster/${var.workspace}-${var.env}-cluster"
              value               = "owned"
              propagate_at_launch = true   
            },
            {
              key                 = "k8s.io/cluster-autoscaler/${var.workspace}-${var.env}-cluster"
              value               = "owned"
              propagate_at_launch = true
            },
            {
              key                 = "k8s.io/cluster-autoscaler/enabled"
              value               = "TRUE"
              propagate_at_launch = true
            },
            {
              key                 = "Workspace"
              value               = var.workspace
              propagate_at_launch = true   
            },
            {
              key                 = "env"
              value               = var.env
              propagate_at_launch = true
            }
          ]
     lifecycle = {
       create_before_destroy = true
  }
  }
}

###########################################-EKS-LOCALS-TAGS-######################################################
locals {
  common_tags = {
    Workspace   = var.workspace
    env = var.env
    Name = "${var.workspace}-${var.env}-cluster"
  }
}
###############################################-EKS_USERS_ROLES-########################################################
locals {
  map_users = [
    {
      userarn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/rahul"
      username = "rahul"
      groups    = ["system:masters"]
    },
  ]

 map_roles = [
    {
      rolearn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/iam-role_${var.workspace}_${var.env}_jumpbox"
      username = "system:node:{{EC2PrivateDNSName}}"
      groups    = ["system:masters"]
    },
]
}

data "aws_caller_identity" "current" {
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "caller_arn" {
  value = data.aws_caller_identity.current.arn
}

output "caller_user" {
  value = data.aws_caller_identity.current.user_id
}

