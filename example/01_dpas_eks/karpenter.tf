# Reference docs:
## https://karpenter.sh/v0.19.3/getting-started/getting-started-with-eksctl/
## https://karpenter.sh/v0.19.3/getting-started/migrating-from-cas/

data "aws_iam_policy_document" "karpenter_controller_trust_policy" {
  count = local.enable_karpenter ? 1 : 0
  statement {
    actions = [
      "ec2:TerminateInstances"
    ]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/Name"

      values = [
        "*karpenter*"
      ]
    }
    sid = "ConditionalEC2Termination"
  }

  statement {
    actions = [
      "ssm:GetParameter",
      "iam:PassRole",
      "ec2:RunInstances",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeAvailabilityZones",
      "ec2:DeleteLaunchTemplate",
      "ec2:CreateTags",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateFleet",
      "ec2:DescribeSpotPriceHistory",
      "pricing:GetProducts"
    ]
    resources = ["*"]
    sid       = "Karpenter"
  }
}

module "role_karpenter_controller" {
  source = "../../k8s_service_account_role"
  count  = local.enable_karpenter ? 1 : 0

  # Default Tags
  owner       = local.owner
  namespace   = local.namespace
  environment = local.environment

  oidc_arn = module.dpas_eks_cluster.oidc_arn
  oidc_url = module.dpas_eks_cluster.oidc_url

  # Additional Tags
  tags = local.tags

  service_account_role = {
    name                      = "svc-${local.cluster_id}-karpenter-controller"
    service_account_namespace = local.karpenter_namespace
    service_account_name      = "*"
    policy                    = data.aws_iam_policy_document.karpenter_controller_trust_policy.0.json
  }

  depends_on = [
    module.dpas_eks_cluster.cluster_id,
  ]
}

resource "helm_release" "karpenter" {
  count = local.enable_karpenter ? 1 : 0

  name      = local.karpenter_release_name
  namespace = local.karpenter_namespace

  create_namespace = local.karpenter_create_namespace

  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = local.karpenter_version

  values = [
    templatefile("${path.module}/config/karpenter.yaml", {
      node_affinity       = jsonencode(local.default_node_affinity)
      cluster_name        = data.aws_eks_cluster.cluster.id
      cluster_endpoint    = data.aws_eks_cluster.cluster.endpoint
      region              = local.region
      service_account_arn = module.role_karpenter_controller.0.role_arn
      instance_profile    = module.dpas_eks_cluster.node_instance_profile
    })
  ]

  lifecycle {
    ignore_changes = [
      repository_password,
    ]
  }

  depends_on = [
    module.dpas_eks_cluster.cluster_id,
    module.role_karpenter_controller
  ]
}



