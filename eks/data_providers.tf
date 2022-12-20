data "aws_partition" "current" {}
data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}
data "aws_canonical_user_id" "current" {}
data "aws_region" "current" {}

locals {
  # VPC
  vpc_id                  = var.create_vpc ? module.vpc[0].vpc_id : var.vpc_id
  vpc_private_subnets     = var.create_vpc ? module.vpc[0].private_subnets : var.private_subnets
  vpc_database_subnets    = var.create_vpc ? module.vpc[0].database_subnets : var.database_subnets
  public_route_table_ids  = var.create_vpc ? module.vpc[0].public_route_table_ids : []
  private_route_table_ids = var.create_vpc ? module.vpc[0].private_route_table_ids : []

  dns_suffix = data.aws_partition.current.dns_suffix
}