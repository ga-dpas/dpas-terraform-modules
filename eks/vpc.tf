# VPC Module
##############################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "v3.14.2"

  count = var.create_vpc ? 1 : 0

  name             = "${var.cluster_id}-vpc"
  cidr             = var.vpc_cidr
  azs              = data.aws_availability_zones.available.names
  public_subnets   = var.public_subnet_cidrs
  private_subnets  = var.private_subnet_cidrs
  database_subnets = var.database_subnet_cidrs

  private_subnet_tags = {
    "SubnetType"                              = "Private"
    "kubernetes.io/cluster/${var.cluster_id}" = "shared"
    "kubernetes.io/role/internal-elb"         = "1"
  }

  public_subnet_tags = {
    "SubnetType"                              = "Utility"
    "kubernetes.io/cluster/${var.cluster_id}" = "shared"
    "kubernetes.io/role/elb"                  = "1"
  }

  database_subnet_tags = {
    "SubnetType" = "Database"
  }

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway           = true
  create_database_subnet_group = true

  tags = merge(
    {
      Name        = "${var.cluster_id}-vpc"
      owner       = var.owner
      namespace   = var.namespace
      environment = var.environment
    },
    var.tags
  )
}

# VPC Endpoints Module
########################################
module "s3_endpoint" {
  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"

  create = var.create_vpc && var.enable_vpc_s3_endpoint

  vpc_id             = local.vpc_id
  security_group_ids = []

  endpoints = {
    s3 = {
      service      = "s3"
      service_type = "Gateway"
      route_table_ids = flatten([
        module.vpc[0].private_route_table_ids,
        module.vpc[0].public_route_table_ids,
      ])
      tags = {
        Name = "${var.cluster_id}-s3-vpc-endpoint"
      }
    },
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