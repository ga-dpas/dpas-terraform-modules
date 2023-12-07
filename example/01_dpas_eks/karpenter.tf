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
################################################################################
data "aws_iam_policy_document" "karpenter_controller_trust_policy" {
  statement {
    actions = [
      "ec2:TerminateInstances",
      "ec2:DeleteLaunchTemplate"
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
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateTags",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets",
      "ec2:RunInstances",
      "pricing:GetProducts"
    ]
    resources = ["*"]
    sid       = "Karpenter"
  }

  statement {
    actions   = ["ssm:GetParameter"]
    resources = ["*"]
  }

  statement {
    actions   = ["iam:PassRole"]
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
}

module "role_karpenter_controller" {
  source = "git@github.com:ga-scr/dpas-terraform-modules.git//k8s_service_account_role?ref=main"

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
      node_selector           = jsonencode(local.node_selector)
      cluster_name            = data.aws_eks_cluster.cluster.id
      cluster_endpoint        = data.aws_eks_cluster.cluster.endpoint
      region                  = local.region
      service_account_arn     = module.role_karpenter_controller.role_arn
      instance_profile        = module.dpas_eks_cluster.node_instance_profile
      interruption_queue_name = local.interruption_queue_name
    })
  ]

  depends_on = [
    module.dpas_eks_cluster.cluster_id,
    module.role_karpenter_controller
  ]
}



