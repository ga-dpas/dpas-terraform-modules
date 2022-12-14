output "cluster_id" {
  value = module.dpas_eks_cluster.cluster_id
}

output "region" {
  value = local.region
}

output "owner" {
  value = local.owner
}

output "namespace" {
  value = local.namespace
}

output "environment" {
  value = local.environment
}

output "node_role_arn" {
  value = module.dpas_eks_cluster.node_role_arn
}

output "node_role_name" {
  value = module.dpas_eks_cluster.node_role_name
}

output "node_instance_profile" {
  value = module.dpas_eks_cluster.node_instance_profile
}

output "node_security_group" {
  value = module.dpas_eks_cluster.node_security_group
}

output "oidc_arn" {
  value = module.dpas_eks_cluster.oidc_arn
}

output "oidc_url" {
  value = module.dpas_eks_cluster.oidc_url
}

output "tags" {
  value = local.tags
}
