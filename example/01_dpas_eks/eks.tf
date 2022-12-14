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

module "dpas_eks_cluster" {
  source = "../../eks"

  # Cluster config
  cluster_id      = local.cluster_id
  cluster_version = local.cluster_version

  # Cluster logs - disabled
  cluster_enabled_log_types           = []
  create_cluster_cloudwatch_log_group = false

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
  create_vpc            = "true"
  vpc_cidr              = local.vpc_cidr
  public_subnet_cidrs   = local.public_subnet_cidrs
  private_subnet_cidrs  = local.private_subnet_cidrs
  database_subnet_cidrs = local.database_subnet_cidrs

  # Nodegroup config
  # This ensures core services such as VPC CNI, CoreDNS, etc. are up and running
  # so that Karpenter can be deployed and start managing compute capacity as required
  default_worker_instance_type = local.default_worker_instance_type
  min_nodes                    = 1
  max_nodes                    = 2
  extra_userdata               = local.extra_userdata
  extra_bootstrap_args         = local.extra_bootstrap_args
  extra_node_labels            = local.extra_node_labels

  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
      addon_version     = local.core_dns_version
    }
    kube-proxy = {
      resolve_conflicts = "OVERWRITE"
      addon_version     = local.kube_proxy_version
    }
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
      addon_version     = local.cni_version
    }
  }

  aws_auth_users = local.aws_auth_users
  aws_auth_roles = local.aws_auth_roles
}
