# VPC Endpoints Module
########################################
module "s3_gateway_endpoint" {
  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"

  create = var.create_vpc && var.enable_vpc_s3_endpoint

  vpc_id             = local.vpc_id
  security_group_ids = []

  endpoints = {
    s3 = {
      service      = "s3"
      service_type = "Gateway"
      route_table_ids = flatten([
        local.private_route_table_ids,
        local.public_route_table_ids,
      ])
      tags = { Name = "${var.cluster_id}-s3-gateway-vpc-endpoint" }
    }
  }

  tags = merge(
    {
      owner       = var.owner
      namespace   = var.namespace
      environment = var.environment
    },
    var.tags
  )
}