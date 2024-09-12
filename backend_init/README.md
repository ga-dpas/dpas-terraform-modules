# Terraform Module: backend_init

The purpose of this module is to provision backend resources to manage DPAS terraform state files.

---

## Introduction

The module provisions the following resource:

- Terraform backend s3 and dynamodb resources to manage terraform state

## Usage

```hcl-terraform
module "backend_init" {
  source = "git@github.com:ga-dpas/dpas-terraform-modules.git//backend_init?ref=main"

  owner       = local.owner
  namespace   = local.namespace
  environment = local.environment

  # Additional Tags
  tags = local.tags
}
```

## Variables

### Inputs
| Name        | Description                                                                                                 |     Type     | Default | Required |
|-------------|-------------------------------------------------------------------------------------------------------------|:------------:|:-------:|:--------:|
| owner       | The owner of the environment                                                                                |    string    |         |   Yes    |
| namespace   | The unique namespace for the environment, which could be your organization name or abbreviation, e.g. 'odc' |    string    |         |   Yes    |
| environment | The name of the environment - e.g. dev, stage                                                               |    string    |         |   Yes    |
| attributes  | Additional attributes (e.g. `region`)                                                                       | list(string) |   []    |    No    |
| delimiter   | Delimiter to be used between `namespace`, `stage`, `name` and `attributes`                                  |    string    |   "-"   |    No    |
| tags        | Additional tags - e.g. `map('StackName','XYZ')`                                                             | map(string)  |   {}    |    No    |

### Outputs
| Name                    | Description                         | Sensitive |
|-------------------------|-------------------------------------|-----------|
| tf_state_bucket         | Terraform state store bucket        | false     |
| tf_state_dynamodb_table | Terraform state lock dynamodb table | false     |
