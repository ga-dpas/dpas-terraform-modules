resource "aws_autoscaling_group" "node" {
  desired_capacity    = var.desired_nodes
  max_size            = var.max_nodes
  min_size            = var.min_nodes
  name                = "${var.cluster_id}-${aws_launch_template.node.id}-node"
  vpc_zone_identifier = local.vpc_private_subnets

  # Don't reset to default size every time terraform is applied
  lifecycle {
    ignore_changes        = [desired_capacity]
    create_before_destroy = true
  }

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  # Use a dynamic tag block rather than tags = [<list of tags>] to workaround this issue https://github.com/hashicorp/terraform-provider-aws/issues/14085
  dynamic "tag" {
    for_each = merge(
      {
        Name        = "${var.cluster_id}-${aws_launch_template.node.id}-node"
        environment = var.environment
        namespace   = var.namespace
        owner       = var.owner

        "kubernetes.io/cluster/${aws_eks_cluster.eks.id}" = "owned"
      },
      var.tags,
      var.extra_node_tags
    )
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  # Don't break cluster autoscaler
  suspended_processes = ["AZRebalance"]

  depends_on = [aws_launch_template.node]
}
