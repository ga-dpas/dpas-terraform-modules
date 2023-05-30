resource "aws_eks_addon" "eks_addons" {
  for_each = { for k, v in var.cluster_addons : k => v }

  cluster_name = aws_eks_cluster.eks.name
  addon_name   = try(each.value.name, each.key)

  addon_version               = lookup(each.value, "addon_version", null)
  resolve_conflicts_on_create = lookup(each.value, "resolve_conflicts", null)
  resolve_conflicts_on_update = lookup(each.value, "resolve_conflicts", null)
  service_account_role_arn    = lookup(each.value, "service_account_role_arn", null)
  configuration_values        = lookup(each.value, "configuration_values", null)

  depends_on = [
    aws_autoscaling_group.node,
    kubernetes_config_map.aws_auth
  ]

  tags = merge(
    {
      Name        = var.cluster_id
      owner       = var.owner
      namespace   = var.namespace
      environment = var.environment
    },
    var.tags
  )
}