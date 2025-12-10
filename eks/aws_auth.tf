locals {
  aws_auth_configmap_data = {
    mapRoles = yamlencode(concat(
      [{
        rolearn  = aws_iam_role.eks_node.arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups = [
          "system:bootstrappers",
          "system:nodes",
        ]
      }],
      var.aws_auth_roles
    ))
    mapUsers    = length(var.aws_auth_users) == 0 ? null : yamlencode(var.aws_auth_users)
    mapAccounts = length(var.aws_auth_accounts) == 0 ? null : yamlencode(var.aws_auth_accounts)
  }
}
resource "kubernetes_config_map_v1" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = local.aws_auth_configmap_data
}

