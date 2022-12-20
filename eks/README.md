# Terraform EKS Setup Module: eks

Terraform module designed to provision an EKS cluster on AWS.

---

## Requirements

[AWS CLI](https://aws.amazon.com/cli/)

[Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

[Helm](https://github.com/kubernetes/helm#install)

[Terraform](https://www.terraform.io/downloads.html)

[Fluxctl](https://docs.fluxcd.io/en/stable/tutorials/get-started.html) -(optional)

## Introduction

The module provisions the following resources:

- Creates AWS EKS cluster in a VPC with subnets
- (Optionally) Creates VPC resources using [terraform-aws-vpc](https://github.com/terraform-aws-modules/terraform-aws-vpc) module with the default configuration and internet facing resources, _or_
- (Optionally) Use a supplied VPC and subnets configured and _tagged_ as required by AWS EKS - see [VPC considerations](https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html) and the requirements on subnet tagging for the [Application load balancing on Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html)

## Usage

The complete terraform AWS example is provided for kick-start [here](https://github.com/ga-scr/dpas-terraform-modules/tree/master/examples).
Copy the example to create your own live repo to set up EKS infrastructure to run dpas processing in your own AWS account.

```terraform
module "dpas_eks" {
  source = "git@github.com:ga-scr/dpas-terraform-modules.git//eks?ref=main"

  # Cluster config
  cluster_id      = local.cluster_id
  cluster_version = local.cluster_version

  # Default Tags
  owner       = local.owner
  namespace   = local.namespace
  environment = local.environment

  # Additional Tags
  tags = local.tags

  # VPC and subnets config
  create_vpc             = "true"
  enable_vpc_s3_endpoint = "true"
  vpc_cidr               = local.vpc_cidr
  public_subnet_cidrs    = local.public_subnet_cidrs
  private_subnet_cidrs   = local.private_subnet_cidrs
  database_subnet_cidrs  = local.database_subnet_cidrs

  # Default nodegroup config
  # This ensures core services such as VPC CNI, CoreDNS, etc. are up and running
  # so that Karpenter can be deployed and start managing compute capacity as required
  default_worker_instance_type = local.default_worker_instance_type
  min_nodes                    = 1
  max_nodes                    = 2
  extra_userdata               = local.extra_userdata
  extra_bootstrap_args         = local.extra_bootstrap_args

  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {
      resolve_conflicts = "OVERWRITE"
    }
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
  }
}
```

## Variables

### Inputs
| Name                                   | Description                                                                                                                                                                                            |     Type     |              Default              | Required |
|----------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:------------:|:---------------------------------:|:--------:|
| owner                                  | The owner of the environment                                                                                                                                                                           |    string    |                                   |   yes    |
| namespace                              | The unique namespace for the environment, which could be your organization name or abbreviation, e.g. 'odc'                                                                                            |    string    |                                   |   yes    |
| environment                            | The name of the environment - e.g. dev, stage                                                                                                                                                          |    string    |                                   |   yes    |
| cluster_id                             | The name of your cluster. Used for the resource naming as identifier                                                                                                                                   |    string    |                                   |   yes    |
| cluster_version                        | EKS Cluster version to use                                                                                                                                                                             |    string    |                                   |   Yes    |
| cluster_enabled_log_types              | A list of the desired control plane logs to enable. See Amazon EKS Control Plane Logging documentation for more information - https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html | list(string) | ["audit", "api", "authenticator"] |    No    |
| create_cluster_cloudwatch_log_group    | Determines whether a log group is created by this module for the cluster logs. If not, AWS will automatically create one if logging is enabled                                                         |     bool     |               true                |    No    |
| cloudwatch_log_group_retention_in_days | Number of days to retain log events. Default retention - 30 days                                                                                                                                       |    number    |                30                 |    No    |
| cloudwatch_log_group_kms_key_id        | If a KMS Key ARN is set, this key will be used to encrypt the corresponding log group                                                                                                                  |    string    |               null                |    No    |
| cluster_addons                         | Map of cluster addon configurations to enable for the cluster. Addon name can be the map keys or set with `name`                                                                                       | map(string)  |                {}                 |    No    |
| create_vpc                             | Determines whether to create the VPC and subnets or to supply them. If supplied then subnets and tagging must be configured correctly for AWS EKS use - see AWS EKS VPC requirements documentation     |     bool     |               false               |    No    |
| vpc_id                                 | ID of the VPC to place EKS in. Use if create_vpc=false                                                                                                                                                 |    string    |                                   |    No    |
| private_subnets                        | List of private subnets to use for EKS cluster setup. Requires if create_vpc = false                                                                                                                   |    string    |                []                 |    No    |
| vpc_cidr                               | The network CIDR you wish to use for the VPC module subnets. Default is set to 10.0.0.0/16 for most use-cases. Requires if create_vpc = true                                                           |    string    |           "10.0.0.0/16"           |    No    |
| public_subnet_cidrs                    | List of public cidrs, for all available availability zones. Used by VPC module to set up public subnets. Requires if create_vpc = true                                                                 | list(string) |                []                 |    No    |
| private_subnet_cidrs                   | List of private cidrs, for all available availability zones. Used by VPC module to set up private subnets. Requires if create_vpc = true                                                               | list(string) |                []                 |    No    |
| database_subnet_cidrs                  | List of database cidrs, for all available availability zones. Used by VPC module to set up database subnets. Requires if create_vpc = true                                                             | list(string) |                []                 |    No    |
| enable_vpc_endpoints                   | Determines whether to creates VPC endpoint resources. Default is set to 'false'                                                                                                                        |     bool     |               false               |    No    |
| vpc_endpoints                          | A map of interface and/or gateway endpoints containing their properties and configurations. Default will create S3 gateway endpoint if 'enable_vpc_endpoints = true'                                   |     any      |                {}                 |    No    |
| public_route_table_ids                 | List of public_route_table_ids for supplied VPC. Requires if create_vpc = false but enable_vpc_s3_endpoint = true                                                                                      | list(string) |                []                 |    No    |
| private_route_table_ids                | List of private_route_table_ids for supplied VPC. Requires if create_vpc = false but enable_vpc_s3_endpoint = true                                                                                     | list(string) |                []                 |    No    |
| admin_access_CIDRs                     | Locks ssh and api access to these IPs                                                                                                                                                                  | map(string)  |                {}                 |    No    |
| ami_image_id                           | This variable can be used to deploy a patched / customised version of the Amazon EKS image                                                                                                             |    string    |                ""                 |    No    |
| default_worker_instance_type           | The default nodegroup worker instance type that the cluster nodes core components will run                                                                                                             |    string    |            m6g.medium             |    No    |
| min_nodes                              | The minimum number of on-demand nodes to run                                                                                                                                                           |    number    |                 0                 |    No    |
| desired_nodes                          | Desired number of nodes only used when first launching the cluster afterwards you should scale with something like cluster-autoscaler                                                                  |    number    |                 0                 |    No    |
| max_nodes                              | Max number of nodes you want to run, useful for controlling max cost of the cluster                                                                                                                    |    number    |                 0                 |    No    |
| root_block_device_mappings             | Specify root EBS volume properties                                                                                                                                                                     |     any      |      <see variables.tf file>      |    No    |
| additional_block_device_mappings       | Specify volumes to attach to the instance besides the volumes specified by the AMI                                                                                                                     |     any      |      <see variables.tf file>      |    No    |
| extra_userdata                         | Additional EC2 user data commands that will be passed to EKS nodes                                                                                                                                     |    string    |      <see variables.tf file>      |    No    |
| extra_kubelet_args                     | Additional kubelet command-line arguments                                                                                                                                                              |    string    |                ""                 |    No    |
| extra_bootstrap_args                   | Additional bootstrap command-line arguments                                                                                                                                                            |    string    |                ""                 |    No    |
| extra_node_labels                      | Additional node labels e.g. 'label1=value1,label2=value2'                                                                                                                                              |    string    |                ""                 |    No    |
| tags                                   | Additional tags - e.g. `map('StackName','XYZ')`                                                                                                                                                        | map(string)  |                {}                 |    No    |
| extra_node_tags                        | Additional tags for EKS nodes (e.g. `map('StackName','XYZ')`                                                                                                                                           | map(string)  |                {}                 |    No    |
| aws_auth_roles                         | List of role maps to add to the aws-auth configmap                                                                                                                                                     | map(string)  |                []                 |    No    |
| aws_auth_users                         | List of user maps to add to the aws-auth configmap                                                                                                                                                     | map(string)  |                []                 |    No    |
| aws_auth_accounts                      | List of account maps to add to the aws-auth configmap                                                                                                                                                  | map(string)  |                []                 |    No    |
| enable_irsa                            | Determines whether to create an OpenID Connect Provider for EKS to enable IRSA                                                                                                                         |     bool     |               true                |    No    |
| openid_connect_audiences               | List of OpenID Connect audience client IDs to add to the IRSA provider                                                                                                                                 | list(string) |                []                 |    No    |
| custom_oidc_thumbprints                | Additional list of server certificate thumbprints for the OpenID Connect (OIDC) identity provider's server certificate(s)                                                                              | list(string) |                []                 |    No    |

### Outputs
| Name                   | Description                                             | Sensitive |
|------------------------|---------------------------------------------------------|-----------|
| cluster_id             | EKS cluster ID                                          | false     |
| cluster_version        | EKS cluster version                                     | false     |
| ami_image_id           | AMI ID used for worker EC2 instance node group          | false     |
| node_instance_profile  | EC2 instance profile for EKS work node group            | false     |
| node_security_group    | security group for EKS work node group                  | false     |
| node_role_arn          | IAM role ARN for EKS work node group                    | false     |
| node_role_name         | IAM role name for EKS work node group                   | false     |
| node_asg_name          | EKS work node group name                                | false     |
| oidc_arn               | EKS cluster OpenID Connect (OIDC) identity provider ARN | false     |
| oidc_url               | EKS cluster OpenID Connect (OIDC) identity provider URL | false     |
| vpc_id                 | EKS cluster VPC ID                                      | false     |
| database_subnets       | List of database subnets                                | false     |
| private_subnets        | List of private subnets                                 | false     |
| public_route_table_ids | Public subnet route table ids                           | false     |