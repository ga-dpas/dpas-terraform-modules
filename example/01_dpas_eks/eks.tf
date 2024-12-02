locals {
  # aws-auth
  aws_auth_roles = concat(
    [for role_name, role_arn in local.aws_iam_admin_roles : {
      rolearn  = role_arn
      username = role_name
      groups   = ["system:masters", ]
    }]
  )
  aws_auth_users = concat(
    [for user_name, user_arn in local.aws_iam_admin_users : {
      rolearn  = user_arn
      username = user_name
      groups   = ["system:masters", ]
    }],
  )
}

########################################################
# VPC CNI Policy
########################################################
# scope-down IAM policy for IPv4 mode - vpc-cni plugin
## Refer Doc: https://github.com/aws/amazon-vpc-cni-k8s/blob/master/docs/iam-policy.md#sample-scope-down-iam-policy-for-ipv4-mode
data "aws_iam_policy_document" "vpc_cni" {
  statement {
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSubnets",
      "ec2:DescribeInstanceTypes"
    ]
    resources = ["*"]
  }

  statement {
    actions   = ["ec2:CreateTags"]
    resources = ["arn:${local.partition}:ec2:*:*:network-interface/*"]
  }

  statement {
    actions   = ["ec2:CreateNetworkInterface"]
    resources = ["arn:${local.partition}:ec2:*:*:network-interface/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/cluster.k8s.amazonaws.com/name"
      values   = [local.cluster_id]
    }
  }

  statement {
    actions = ["ec2:CreateNetworkInterface"]
    resources = [
      "arn:${local.partition}:ec2:*:*:subnet/*",
      "arn:${local.partition}:ec2:*:*:security-group/*"
    ]
    condition {
      test     = "ArnEquals"
      variable = "ec2:Vpc"
      values = [
        "arn:${local.partition}:ec2:*:*:vpc/${module.dpas_eks_cluster.vpc_id}"
      ]
    }
  }

  statement {
    actions = [
      "ec2:DeleteNetworkInterface",
      "ec2:UnassignPrivateIpAddresses",
      "ec2:AssignPrivateIpAddresses",
      "ec2:AttachNetworkInterface",
      "ec2:DetachNetworkInterface",
      "ec2:ModifyNetworkInterfaceAttribute"
    ]
    resources = [
      "arn:${local.partition}:ec2:*:*:network-interface/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/cluster.k8s.amazonaws.com/name"
      values   = [local.cluster_id]
    }
  }

  statement {
    actions = [
      "ec2:AttachNetworkInterface",
      "ec2:DetachNetworkInterface",
      "ec2:ModifyNetworkInterfaceAttribute"
    ]
    resources = [
      "arn:${local.partition}:ec2:*:*:instance/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${local.cluster_id}"
      values   = ["owned"]
    }
  }

  statement {
    actions = [
      "ec2:ModifyNetworkInterfaceAttribute"
    ]
    resources = [
      "arn:${local.partition}:ec2:*:*:security-group/*"
    ]
  }
}

module "role_vpc_cni" {
  source = "git@github.com:ga-dpas/dpas-terraform-modules.git//k8s_service_account_role?ref=main"

  # Default Tags
  owner       = local.owner
  namespace   = local.namespace
  environment = local.environment

  oidc_arn = module.dpas_eks_cluster.oidc_arn == null ? "" : module.dpas_eks_cluster.oidc_arn
  oidc_url = module.dpas_eks_cluster.oidc_url == null ? "https://" : module.dpas_eks_cluster.oidc_url

  # Additional Tags
  tags = local.tags

  service_account_role = {
    name                      = "svc-${local.cluster_id}-vpc-cni"
    service_account_namespace = "kube-system"
    service_account_name      = "aws-node"
    policy                    = data.aws_iam_policy_document.vpc_cni.json
  }
}

########################################################
# EBS CSI Driver Policy
########################################################
# https://github.com/kubernetes-sigs/aws-ebs-csi-driver/blob/master/docs/example-iam-policy.json
data "aws_iam_policy_document" "ebs_csi_driver" {
  statement {
    actions = [
      "ec2:CreateSnapshot",
      "ec2:AttachVolume",
      "ec2:DetachVolume",
      "ec2:ModifyVolume",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInstances",
      "ec2:DescribeSnapshots",
      "ec2:DescribeTags",
      "ec2:DescribeVolumes",
      "ec2:DescribeVolumesModifications",
    ]
    resources = ["*"]
  }

  statement {
    actions = ["ec2:CreateTags"]
    resources = [
      "arn:${local.partition}:ec2:*:*:volume/*",
      "arn:${local.partition}:ec2:*:*:snapshot/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values = [
        "CreateVolume",
        "CreateSnapshot",
      ]
    }
  }

  statement {
    actions = ["ec2:DeleteTags"]
    resources = [
      "arn:${local.partition}:ec2:*:*:volume/*",
      "arn:${local.partition}:ec2:*:*:snapshot/*",
    ]
  }

  statement {
    actions   = ["ec2:CreateVolume"]
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/ebs.csi.aws.com/cluster"
      values   = [true]
    }
  }

  statement {
    actions   = ["ec2:CreateVolume"]
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/CSIVolumeName"
      values   = ["*"]
    }
  }

  statement {
    actions   = ["ec2:CreateVolume"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${local.cluster_id}"
      values   = ["owned"]
    }
  }

  statement {
    actions   = ["ec2:DeleteVolume"]
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/ebs.csi.aws.com/cluster"
      values   = [true]
    }
  }

  statement {
    actions   = ["ec2:DeleteVolume"]
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/CSIVolumeName"
      values   = ["*"]
    }
  }

  statement {
    actions   = ["ec2:DeleteVolume"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/kubernetes.io/cluster/${local.cluster_id}"
      values   = ["owned"]
    }
  }

  statement {
    actions   = ["ec2:DeleteVolume"]
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/kubernetes.io/created-for/pvc/name"
      values   = ["*"]
    }
  }

  statement {
    actions   = ["ec2:DeleteSnapshot"]
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/CSIVolumeSnapshotName"
      values   = ["*"]
    }
  }

  statement {
    actions   = ["ec2:DeleteSnapshot"]
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/ebs.csi.aws.com/cluster"
      values   = [true]
    }
  }
}

module "role_ebs_csi_driver" {
  source = "git@github.com:ga-dpas/dpas-terraform-modules.git//k8s_service_account_role?ref=main"

  # Default Tags
  owner       = local.owner
  namespace   = local.namespace
  environment = local.environment

  oidc_arn = module.dpas_eks_cluster.oidc_arn == null ? "" : module.dpas_eks_cluster.oidc_arn
  oidc_url = module.dpas_eks_cluster.oidc_url == null ? "https://" : module.dpas_eks_cluster.oidc_url

  # Additional Tags
  tags = local.tags

  service_account_role = {
    name                      = "svc-${local.cluster_id}-ebs-csi-driver"
    service_account_namespace = "kube-system"
    service_account_name      = "ebs-csi-controller-sa"
    policy                    = data.aws_iam_policy_document.ebs_csi_driver.json
  }
}

########################################################
# EKS setup
########################################################
locals {
  vpc_cni_config        = file("${path.module}/config/vpc_cni.json")
  kube_proxy_config     = file("${path.module}/config/kube_proxy.json")
  ebs_csi_driver_config = file("${path.module}/config/ebs_csi_driver.json")
}

module "dpas_eks_cluster" {
  source = "../../eks"

  # Cluster config
  cluster_id      = local.cluster_id
  cluster_version = local.cluster_version

  create_cluster_cloudwatch_log_group = false

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true # NOTE: If disabled, control plane will be accessible only from the VPC or connected networks

  # Default Tags
  owner       = local.owner
  namespace   = local.namespace
  environment = local.environment

  # Additional Tags
  tags = merge(
    {
      # Tag for Karpenter auto-discovery - subnets and security groups
      "karpenter.sh/discovery" = local.cluster_id
    },
    local.tags
  )

  # VPC and subnets config
  create_vpc                   = true
  enable_vpc_s3_endpoint       = true
  create_database_subnet_group = false # NOTE: This is created in db module instead
  vpc_cidr                     = local.vpc_cidr
  public_subnet_cidrs          = local.public_subnet_cidrs
  private_subnet_cidrs         = local.private_subnet_cidrs
  database_subnet_cidrs        = local.database_subnet_cidrs

  # Nodegroup config
  # This ensures core services such as VPC CNI, CoreDNS, etc. are up and running
  # so that Karpenter can be deployed and start managing compute capacity as required
  ami_id                       = local.ami_id
  ami_type                     = local.ami_type
  default_worker_instance_type = local.default_worker_instance_type
  min_nodes                    = 2
  max_nodes                    = 2
  node_labels                  = local.node_labels
  extra_userdata               = local.extra_userdata
  # setting instance to use IMDSv2
  ## Refer: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html
  metadata_options = local.node_metadata_options

  iam_role_attach_cni_policy = false

  cluster_addons = {
    coredns = {
      resolve_conflicts    = "OVERWRITE"
      addon_version        = local.core_dns_version
      configuration_values = templatefile("${path.module}/config/core_dns.json", { replica_count = "1" })
    }
    kube-proxy = {
      resolve_conflicts    = "OVERWRITE"
      addon_version        = local.kube_proxy_version
      configuration_values = local.kube_proxy_config
    }
    vpc-cni = {
      resolve_conflicts        = "OVERWRITE"
      addon_version            = local.cni_version
      service_account_role_arn = module.role_vpc_cni.role_arn
      configuration_values     = local.vpc_cni_config
    }
    # NOTE: required ebs-csi add-ons for gp3 pvc
    aws-ebs-csi-driver = {
      resolve_conflicts        = "OVERWRITE"
      addon_version            = local.aws_ebs_csi_driver_version
      service_account_role_arn = module.role_ebs_csi_driver.role_arn
      configuration_values     = local.ebs_csi_driver_config
    }
  }

  aws_auth_users = local.aws_auth_users
  aws_auth_roles = local.aws_auth_roles
}
