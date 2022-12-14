data "aws_partition" "current" {}
data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}
data "aws_canonical_user_id" "current" {}
data "aws_region" "current" {}

locals {
  vpc_id              = var.create_vpc ? module.vpc[0].vpc_id : var.vpc_id
  vpc_private_subnets = var.create_vpc ? module.vpc[0].private_subnets : var.private_subnets

  dns_suffix = data.aws_partition.current.dns_suffix
}