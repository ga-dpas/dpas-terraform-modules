module "cluster_label" {
  source = "cloudposse/label/null"

  namespace = local.namespace
  stage     = local.environment
  name      = "eks"
  delimiter = "-"
}

data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}
data "aws_canonical_user_id" "current" {}
data "aws_partition" "current" {}
data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}
data "aws_eks_cluster" "cluster" {
  name = module.dpas_eks_cluster.cluster_id
}
data "aws_eks_cluster_auth" "cluster" {
  name = module.dpas_eks_cluster.cluster_id
}
data "aws_ami" "cluster_ami" {
  filter {
    name   = "name"
    values = ["amazon-eks-arm64-node-${local.cluster_version}-v*"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI Account ID
}

locals {
  region      = "ap-southeast-2"
  owner       = "scr"
  namespace   = "dpas"
  environment = "sandbox"

  cluster_version = 1.26
  cluster_id      = module.cluster_label.id

  partition  = data.aws_partition.current.partition
  dns_suffix = data.aws_partition.current.dns_suffix

  # VPC
  enable_s3_endpoint    = true
  enable_nat_gateway    = true
  vpc_cidr              = "10.35.0.0/16"
  public_subnet_cidrs   = ["10.35.0.0/22", "10.35.4.0/22", "10.35.8.0/22"]
  private_subnet_cidrs  = ["10.35.32.0/19", "10.35.64.0/19", "10.35.96.0/19"]
  database_subnet_cidrs = ["10.35.20.0/22", "10.35.24.0/22", "10.35.28.0/22"]

  # EKS add-ons
  cni_version                = "v1.15.4-eksbuild.1"
  kube_proxy_version         = "v1.26.9-eksbuild.2"
  core_dns_version           = "v1.9.3-eksbuild.10"
  aws_ebs_csi_driver_version = "v1.25.0-eksbuild.1"

  # EKS Node
  ami_image_id                 = data.aws_ami.cluster_ami.id
  default_worker_instance_type = "m6g.xlarge"
  extra_bootstrap_args         = "--container-runtime containerd"
  # node labels - can be use for node affinity configurations
  default_node_group = "eks-default"
  default_node_type  = "ondemand"
  extra_node_labels  = "nodegroup=${local.default_node_group},nodetype=${local.default_node_type}"
  # default node selector
  node_selector = {
    "nodegroup" : local.default_node_group,
    "nodetype" : local.default_node_type,
    "kubernetes.io/arch" : "arm64",
    "kubernetes.io/os" : "linux"
  }
  # instance userdata
  extra_userdata = <<-USERDATA
  REGION=${local.region}
  EC2_NAME=SCR-DPAS-$HOSTNAME
  ## Enable ssm-agent
  #########################
  sudo systemctl enable amazon-ssm-agent
  sudo systemctl start amazon-ssm-agent
  #########################
  USERDATA

  # k8s defaults
  # k8s aws-auth for authentication
  aws_iam_admin_users = {
    # <user-name> = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/<user-name>"
  }
  aws_iam_admin_roles = {
    # <role> : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/<role>"
  }
  # node affinity - Used for karpenter affinity configuration
  default_node_affinity = {
    nodeAffinity : {
      requiredDuringSchedulingIgnoredDuringExecution : {
        nodeSelectorTerms : [{
          matchExpressions : [
            {
              key : "nodetype"
              operator : "In"
              values : [local.default_node_type]
            },
            {
              key : "nodegroup"
              operator : "In"
              values : [local.default_node_group]
            },
          ]
        }]
      }
    }
  }

  # Karpenter
  enable_karpenter           = true
  karpenter_namespace        = "karpenter"
  karpenter_create_namespace = true
  karpenter_release_name     = "karpenter"
  karpenter_version          = "v0.31.3"

  # Flux2
  enable_flux2               = true
  flux2_namespace            = "flux-system"
  flux2_create_namespace     = true
  flux2_version              = "2.9.0"
  flux2_notification_version = "1.10.0"
  flux2_sync_version         = "1.6.0"

  # provide organisation tags
  tags = {
    "stack_name" = module.cluster_label.id
    "department" = "-"
    "division"   = "-"
    "branch"     = "-"
    "cost_code"  = "-"
    "project"    = "-"
  }
}


