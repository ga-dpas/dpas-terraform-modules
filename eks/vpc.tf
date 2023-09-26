# VPC Module
##############################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "v5.1.2"

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

  # One NAT Gateway per subnet (default behavior)
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = false

  manage_default_network_acl    = false
  manage_default_route_table    = false
  manage_default_security_group = false
  map_public_ip_on_launch       = false

  create_database_subnet_group = var.create_database_subnet_group
  database_subnet_group_name   = var.database_subnet_group_name

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
