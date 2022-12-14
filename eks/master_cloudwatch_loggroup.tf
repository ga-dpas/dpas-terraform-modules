resource "aws_cloudwatch_log_group" "eks_cluster" {
  count = var.create_cluster_cloudwatch_log_group ? 1 : 0

  name              = "/aws/eks/${var.cluster_id}/cluster"
  retention_in_days = var.cloudwatch_log_group_retention_in_days
  kms_key_id        = var.cloudwatch_log_group_kms_key_id

  tags = merge(
    {
      owner       = var.owner
      namespace   = var.namespace
      environment = var.environment
    },
    var.tags
  )
}