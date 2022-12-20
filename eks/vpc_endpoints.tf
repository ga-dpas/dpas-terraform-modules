# VPC Endpoints Module
########################################
module "endpoints" {
  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"

  create = var.enable_vpc_endpoints

  vpc_id             = local.vpc_id
  security_group_ids = []

  endpoints = local.vpc_endpoints

  tags = merge(
    {
      owner       = var.owner
      namespace   = var.namespace
      environment = var.environment
    },
    var.tags
  )
}