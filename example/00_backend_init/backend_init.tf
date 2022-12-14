locals {
  region      = "ap-southeast-2"
  owner       = "scr"
  namespace   = "dpas"
  environment = "sandbox"
}

module "backend_init" {
  source = "../../backend_init"

  owner       = local.owner
  namespace   = local.namespace
  environment = local.environment

  # Additional Tags
  tags = {
    "stack_name" = "${local.namespace}-${local.environment}-eks"
    "department" = "-"
    "division"   = "-"
    "branch"     = "-"
    "cost_code"  = "-"
    "project"    = "-"
  }
}