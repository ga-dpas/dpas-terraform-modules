resource "aws_eks_cluster" "eks" {
  name                      = var.cluster_id
  role_arn                  = aws_iam_role.eks_cluster.arn
  version                   = var.cluster_version
  enabled_cluster_log_types = var.cluster_enabled_log_types

  vpc_config {
    security_group_ids      = [aws_security_group.eks_cluster.id]
    subnet_ids              = local.vpc_private_subnets
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks-cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks-cluster-AmazonEKSServicePolicy,
    aws_cloudwatch_log_group.eks_cluster
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

# wait for eks cluster to be healthy
resource "null_resource" "wait_for_cluster" {

  depends_on = [
    aws_eks_cluster.eks,
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/sh", "-c"]
    command     = "for i in `seq 1 60`; do if `command -v wget > /dev/null`; then wget --no-check-certificate -O - -q $ENDPOINT/healthz >/dev/null && exit 0 || true; else curl -k -s $ENDPOINT/healthz >/dev/null && exit 0 || true;fi; sleep 5; done; echo TIMEOUT && exit 1"
    environment = {
      ENDPOINT = aws_eks_cluster.eks.endpoint
    }
  }
}