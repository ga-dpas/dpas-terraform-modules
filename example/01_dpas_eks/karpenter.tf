# Reference docs:
## https://karpenter.sh/v0.19.3/getting-started/getting-started-with-eksctl/
## https://karpenter.sh/v0.19.3/getting-started/migrating-from-cas/

locals {
  enable_spot_termination = true
  interruption_queue_name = "karpenter-${local.cluster_id}"
  events = {
    health_event = {
      name        = "HealthEvent"
      description = "Karpenter interrupt - AWS health event"
      event_pattern = {
        source      = ["aws.health"]
        detail-type = ["AWS Health Event"]
      }
    }
    spot_interupt = {
      name        = "SpotInterrupt"
      description = "Karpenter interrupt - EC2 spot instance interruption warning"
      event_pattern = {
        source      = ["aws.ec2"]
        detail-type = ["EC2 Spot Instance Interruption Warning"]
      }
    }
    instance_rebalance = {
      name        = "InstanceRebalance"
      description = "Karpenter interrupt - EC2 instance rebalance recommendation"
      event_pattern = {
        source      = ["aws.ec2"]
        detail-type = ["EC2 Instance Rebalance Recommendation"]
      }
    }
    instance_state_change = {
      name        = "InstanceStateChange"
      description = "Karpenter interrupt - EC2 instance state-change notification"
      event_pattern = {
        source      = ["aws.ec2"]
        detail-type = ["EC2 Instance State-change Notification"]
      }
    }
  }
}

################################################################################
# Karpenter controller IAM Role for Service Account (IRSA)
# Reference: https://github.com/marcincuber/eks/blob/main/terraform/oidc-iam-policies.tf#L335
################################################################################
data "aws_iam_policy_document" "karpenter_controller_trust_policy" {
  statement {
    sid = "AllowScopedEC2InstanceActions"
    actions = [
      "ec2:RunInstances",
      "ec2:CreateFleet"
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}::image/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}::snapshot/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:*:spot-instances-request/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:*:security-group/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:*:subnet/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:*:launch-template/*"
    ]
  }

  statement {
    sid = "AllowScopedEC2InstanceActionsWithTags"
    actions = [
      "ec2:RunInstances",
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate"
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:*:fleet/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:*:instance/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:*:volume/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:*:network-interface/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:*:launch-template/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${local.cluster_id}"
      values   = ["owned"]
    }

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.sh/nodepool"
      values   = ["*"]
    }
  }

  statement {
    sid = "AllowScopedResourceCreationTagging"
    actions = [
      "ec2:CreateTags"
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:*:fleet/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:*:instance/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:*:spot-instances-request/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:*:volume/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:*:network-interface/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:*:launch-template/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${local.cluster_id}"
      values   = ["owned"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks:eks-cluster-name"
      values = [
        local.cluster_id
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values = [
        "RunInstances",
        "CreateFleet",
        "CreateLaunchTemplate"
      ]
    }

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.sh/nodepool"
      values   = ["*"]
    }
  }

  statement {
    sid = "AllowScopedResourceTagging"
    actions = [
      "ec2:CreateTags"
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:*:instance/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${local.cluster_id}"
      values   = ["owned"]
    }

    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.sh/nodepool"
      values   = ["*"]
    }

    condition {
      test     = "StringEqualsIfExists"
      variable = "aws:RequestTag/eks:eks-cluster-name"
      values = [
        local.cluster_id
      ]
    }

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "aws:TagKeys"
      values = [
        "eks:eks-cluster-name",
        "karpenter.sh/nodeclaim",
        "Name"
      ]
    }
  }

  statement {
    sid = "AllowScopedDeletion"
    actions = [
      "ec2:TerminateInstances",
      "ec2:DeleteLaunchTemplate"
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:*:instance/*",
      "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:*:launch-template/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${local.cluster_id}"
      values   = ["owned"]
    }

    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.sh/nodepool"
      values   = ["*"]
    }
  }

  statement {
    sid = "AllowRegionalReadActions"
    actions = [
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [data.aws_region.current.region]
    }
  }

  statement {
    sid = "AllowSSMReadActions"
    actions = [
      "ssm:GetParameter"
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.region}::parameter/aws/service/*"
    ]
  }

  statement {
    sid = "AllowPricingReadActions"
    actions = [
      "pricing:GetProducts"
    ]

    resources = ["*"]
  }

  dynamic "statement" {
    for_each = local.enable_spot_termination ? [1] : []

    content {
      actions = [
        "sqs:DeleteMessage",
        "sqs:GetQueueUrl",
        "sqs:GetQueueAttributes",
        "sqs:ReceiveMessage",
      ]
      resources = [aws_sqs_queue.interruption_queue[0].arn]
    }
  }

  statement {
    sid = "AllowPassingInstanceRole"
    actions = [
      "iam:PassRole",
    ]

    resources = [module.dpas_eks_cluster.node_role_arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values = [
        "ec2.amazonaws.com"
      ]
    }
  }

  statement {
    sid = "AllowScopedInstanceProfileCreationActions"
    actions = [
      "iam:CreateInstanceProfile"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${local.cluster_id}"
      values   = ["owned"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/topology.kubernetes.io/region"
      values   = [data.aws_region.current.region]
    }


    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass"
      values   = ["*"]
    }
  }

  statement {
    sid = "AllowScopedInstanceProfileTagActions"
    actions = [
      "iam:TagInstanceProfile"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${local.cluster_id}"
      values   = ["owned"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/topology.kubernetes.io/region"
      values   = [data.aws_region.current.region]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${local.cluster_id}"
      values   = ["owned"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/topology.kubernetes.io/region"
      values   = [data.aws_region.current.region]
    }


    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass"
      values   = ["*"]
    }

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass"
      values   = ["*"]
    }
  }

  statement {
    sid = "AllowScopedInstanceProfileActions"
    actions = [
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:DeleteInstanceProfile"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${local.cluster_id}"
      values   = ["owned"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/topology.kubernetes.io/region"
      values   = [data.aws_region.current.region]
    }


    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass"
      values   = ["*"]
    }
  }

  statement {
    sid = "AllowInstanceProfileReadActions"
    actions = [
      "iam:GetInstanceProfile"
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "eks:DescribeCluster",
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:eks:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:cluster/${local.cluster_id}",
    ]
  }
}

module "role_karpenter_controller" {
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
    name                      = "svc-${local.cluster_id}-karpenter-controller"
    service_account_namespace = local.karpenter_namespace
    service_account_name      = "karpenter"
    policy                    = data.aws_iam_policy_document.karpenter_controller_trust_policy.json
  }

  depends_on = [
    module.dpas_eks_cluster.cluster_id,
  ]
}

################################################################################
# Node Termination Queue
################################################################################
resource "aws_sqs_queue" "interruption_queue" {
  count = local.enable_spot_termination ? 1 : 0

  name                      = local.interruption_queue_name
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true
  tags = merge(
    {
      name        = local.interruption_queue_name
      owner       = local.owner
      namespace   = local.namespace
      environment = local.environment
    },
    local.tags
  )
}

data "aws_iam_policy_document" "queue" {
  count = local.enable_spot_termination ? 1 : 0

  statement {
    sid       = "SqsWrite"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.interruption_queue[0].arn]

    principals {
      type = "Service"
      identifiers = [
        "events.${local.dns_suffix}",
        "sqs.${local.dns_suffix}",
      ]
    }
  }
}

resource "aws_sqs_queue_policy" "this" {
  count = local.enable_spot_termination ? 1 : 0

  queue_url = aws_sqs_queue.interruption_queue[0].url
  policy    = data.aws_iam_policy_document.queue[0].json
}

################################################################################
# Node Termination Event Rules
################################################################################
resource "aws_cloudwatch_event_rule" "this" {
  for_each = { for k, v in local.events : k => v if local.enable_spot_termination }

  name_prefix   = "Karpenter${each.value.name}-"
  description   = each.value.description
  event_pattern = jsonencode(each.value.event_pattern)

  tags = merge(
    {
      ClusterName : local.cluster_id
    },
    local.tags,
  )
}

resource "aws_cloudwatch_event_target" "this" {
  for_each = { for k, v in local.events : k => v if local.enable_spot_termination }

  rule      = aws_cloudwatch_event_rule.this[each.key].name
  target_id = "KarpenterInterruptionQueueTarget"
  arn       = aws_sqs_queue.interruption_queue[0].arn
}

################################################################################
# Install Karpenter
## Helm chat: https://github.com/aws/karpenter/tree/main/charts/karpenter
################################################################################
resource "helm_release" "karpenter_crd" {
  depends_on = [module.dpas_eks_cluster]

  name      = "karpenter-crd"
  namespace = local.karpenter_namespace

  create_namespace = local.karpenter_create_namespace

  repository   = "oci://public.ecr.aws/karpenter"
  chart        = "karpenter-crd"
  version      = local.karpenter_version
  replace      = true
  force_update = true
}

resource "helm_release" "karpenter" {
  name      = local.karpenter_release_name
  namespace = local.karpenter_namespace

  create_namespace = local.karpenter_create_namespace

  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = local.karpenter_version

  values = [
    templatefile("${path.module}/config/karpenter.yaml", {
      node_selector           = jsonencode(local.node_selector)
      cluster_name            = data.aws_eks_cluster.cluster.id
      cluster_endpoint        = data.aws_eks_cluster.cluster.endpoint
      region                  = local.region
      service_account_arn     = module.role_karpenter_controller.role_arn
      interruption_queue_name = local.interruption_queue_name
    })
  ]

  depends_on = [
    module.dpas_eks_cluster.cluster_id,
    module.role_karpenter_controller,
    helm_release.karpenter_crd
  ]
}

# Ref: https://karpenter.sh/docs/troubleshooting/#missing-service-linked-role
data "aws_iam_role" "service_linked_role_ec2_spot" {
  name = "AWSServiceRoleForEC2Spot"
}

resource "aws_iam_service_linked_role" "service_linked_role_ec2_spot" {
  count = data.aws_iam_role.service_linked_role_ec2_spot.id != "" ? 0 : 1

  aws_service_name = "spot.amazonaws.com"
}