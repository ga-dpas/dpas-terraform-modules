# Terraform Module: eks

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
- (Optionally) Creates VPC with VPC S3 gateway endpoint using [terraform-aws-vpc](https://github.com/terraform-aws-modules/terraform-aws-vpc) module with the default configuration and internet facing resources, _or_
- (Optionally) Supply VPC and subnets configuration as required by AWS EKS cluster setup - see [VPC considerations](https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html) and the requirements on subnet tagging for the [Application load balancing on Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html)

## Usage

The complete terraform AWS example is provided for kick-start [here](https://github.com/ga-dpas/dpas-terraform-modules/tree/master/examples).
Copy the example to create your own live repo to set up EKS infrastructure to run dpas processing in your own AWS account.

```terraform
module "dpas_eks" {
  source = "git@github.com:ga-dpas/dpas-terraform-modules.git//eks?ref=main"

  # Cluster config
  cluster_id      = local.cluster_id
  cluster_version = local.cluster_version

  cluster_endpoint_public_access  = true
  
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
  bootstrap_extra_args         = local.bootstrap_extra_args

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
| Name                                   | Description                                                                                                                                                                                                                                                                        |     Type     |              Default              | Required |
|----------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:------------:|:---------------------------------:|:--------:|
| owner                                  | The owner of the environment                                                                                                                                                                                                                                                       |    string    |                                   |   yes    |
| namespace                              | The unique namespace for the environment, which could be your organization name or abbreviation, e.g. 'odc'                                                                                                                                                                        |    string    |                                   |   yes    |
| environment                            | The name of the environment - e.g. dev, stage                                                                                                                                                                                                                                      |    string    |                                   |   yes    |
| cluster_id                             | The name of your cluster. Used for the resource naming as identifier                                                                                                                                                                                                               |    string    |                                   |   yes    |
| cluster_version                        | EKS Cluster version to use                                                                                                                                                                                                                                                         |    string    |                                   |   Yes    |
| cluster_endpoint_private_access        | Indicates whether or not the Amazon EKS private API server endpoint is enabled                                                                                                                                                                                                     |    string    |               true                |    No    |
| cluster_endpoint_public_access         | Indicates whether or not the Amazon EKS public API server endpoint is enabled                                                                                                                                                                                                      |    string    |               false               |    No    |
| cluster_endpoint_public_access_cidrs   | List of CIDR blocks which can access the Amazon EKS public API server endpoint                                                                                                                                                                                                     | list(string) |           ["0.0.0.0/0"]           |    No    |
| cluster_ip_family                      | The IP family used to assign Kubernetes pod and service addresses. Valid values are `ipv4` (default) and `ipv6`. You can only specify an IP family when you create a cluster, changing this value will force a new cluster to be created                                           |    string    |              "ipv4"               |    No    |
| cluster_service_cidr                   | The CIDR block to assign Kubernetes service IP addresses from. If you don't specify a block, Kubernetes assigns addresses from 172.20.0.0/16 CIDR blocks                                                                                                                           |    string    |          "172.20.0.0/16"          |    No    |
| create_cluster_cloudwatch_log_group    | Determines whether a log group is created by this module for the cluster logs. If not, AWS will automatically create one if logging is enabled                                                                                                                                     |     bool     |               true                |    No    |
| cloudwatch_log_group_retention_in_days | Number of days to retain log events. Default retention - 30 days                                                                                                                                                                                                                   |    number    |                30                 |    No    |
| cloudwatch_log_group_kms_key_id        | If a KMS Key ARN is set, this key will be used to encrypt the corresponding log group                                                                                                                                                                                              |    string    |               null                |    No    |
| cluster_enabled_log_types              | A list of the desired control plane logs to enable. See Amazon EKS Control Plane Logging documentation for more information - https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html                                                                             | list(string) | ["audit", "api", "authenticator"] |    No    |
| cluster_addons                         | Map of cluster addon configurations to enable for the cluster. Addon name can be the map keys or set with `name`                                                                                                                                                                   | map(string)  |                {}                 |    No    |
| create_vpc                             | Determines whether to create the VPC and subnets or to supply them. If supplied then subnets and tagging must be configured correctly for AWS EKS use - see AWS EKS VPC requirements documentation                                                                                 |     bool     |               false               |    No    |
| vpc_id                                 | ID of the VPC to place EKS cluster in. Use if create_vpc=false                                                                                                                                                                                                                     |    string    |                                   |    No    |
| private_subnets                        | List of private subnets to use for EKS cluster setup. Requires if create_vpc = false                                                                                                                                                                                               |    string    |                []                 |    No    |
| database_subnets                       | List of database subnets to use for database cluster setup. Requires if create_vpc = false                                                                                                                                                                                         |    string    |                []                 |    No    |
| vpc_cidr                               | The network CIDR you wish to use for the VPC module subnets. Default is set to 10.0.0.0/16 for most use-cases. Requires if create_vpc = true                                                                                                                                       |    string    |           "10.0.0.0/16"           |    No    |
| public_subnet_cidrs                    | List of public cidrs, for all available availability zones. Used by VPC module to set up public subnets. Requires if create_vpc = true                                                                                                                                             | list(string) |                []                 |    No    |
| private_subnet_cidrs                   | List of private cidrs, for all available availability zones. Used by VPC module to set up private subnets. Requires if create_vpc = true                                                                                                                                           | list(string) |                []                 |    No    |
| database_subnet_cidrs                  | List of database cidrs, for all available availability zones. Used by VPC module to set up database subnets. Requires if create_vpc = true                                                                                                                                         | list(string) |                []                 |    No    |
| create_database_subnet_group           | Determines whether to create database subnet group. Default is set to true. Requires if create_vpc = true                                                                                                                                                                          |     bool     |               true                |    No    |
| database_subnet_group_name             | Name of database subnet group to create by VPC module. Default is set to vpc name if not provided. Requires if create_vpc = true                                                                                                                                                   |    string    |               null                |    No    |
| enable_vpc_s3_endpoint                 | Determines whether to creates VPC S3 gateway endpoint resource. Default is set to 'false'                                                                                                                                                                                          |     bool     |               false               |    No    |
| admin_access_CIDRs                     | Locks ssh and api access to these IPs                                                                                                                                                                                                                                              | map(string)  |                {}                 |    No    |
| ami_id                                 | The AMI from which to launch the instance. If not supplied, defaults to Amazon Linux2 AL2_x86_64 latest AMI                                                                                                                                                                        |    string    |                ""                 |    No    |
| ami_type                               | Type of Amazon Machine Image (AMI) associated with the EKS Node Group. Only supported Amazon Linux (AL2_ and AL2023_) types. See the [AWS documentation](https://docs.aws.amazon.com/eks/latest/APIReference/API_Nodegroup.html#AmazonEKS-Type-Nodegroup-amiType) for valid values |    string    |           "AL2_x86_64"            |    No    |
| default_worker_instance_type           | The default nodegroup worker instance type that the cluster nodes core components will run                                                                                                                                                                                         |    string    |            m6g.medium             |    No    |
| min_nodes                              | The minimum number of on-demand nodes to run                                                                                                                                                                                                                                       |    number    |                 0                 |    No    |
| desired_nodes                          | Desired number of nodes only used when first launching the cluster afterwards you should scale with something like cluster-autoscaler                                                                                                                                              |    number    |                 0                 |    No    |
| max_nodes                              | Max number of nodes you want to run, useful for controlling max cost of the cluster                                                                                                                                                                                                |    number    |                 0                 |    No    |
| root_block_device_mappings             | Specify root EBS volume properties                                                                                                                                                                                                                                                 |     any      |      <see variables.tf file>      |    No    |
| additional_block_device_mappings       | Specify volumes to attach to the instance besides the volumes specified by the AMI                                                                                                                                                                                                 |     any      |      <see variables.tf file>      |    No    |
| metadata_options                       | The metadata options for the instance launch-template. This specifies the exposure of the Instance Metadata Service to worker nodes. Default is set to uses IMSv1                                                                                                                  |     any      |      <see variables.tf file>      |    No    |
| bootstrap_extra_args                   | Additional arguments passed to the bootstrap script (e.g. '--arg1=value --arg2')                                                                                                                                                                                                   |    string    |                ""                 |    No    |
| node_labels                            | Add node labels to worker nodes                                                                                                                                                                                                                                                    |    string    |                ""                 |    No    |
| extra_userdata                         | Additional EC2 user data commands that will be passed to EKS nodes                                                                                                                                                                                                                 |    string    |      <see variables.tf file>      |    No    |
| iam_role_attach_cni_policy             | Whether to attach the `AmazonEKS_CNI_Policy` IAM policy to the worker role. WARNING: If set `false` the permissions must be assigned to the `aws-node` DaemonSet pods via another method or nodes will not be able to join the cluster                                             |     bool     |               true                |    No    |
| tags                                   | Additional tags - e.g. `map('StackName','XYZ')`                                                                                                                                                                                                                                    | map(string)  |                {}                 |    No    |
| extra_node_tags                        | Additional tags for EKS nodes (e.g. `map('StackName','XYZ')`                                                                                                                                                                                                                       | map(string)  |                {}                 |    No    |
| aws_auth_roles                         | List of role maps to add to the aws-auth configmap                                                                                                                                                                                                                                 | map(string)  |                []                 |    No    |
| aws_auth_users                         | List of user maps to add to the aws-auth configmap                                                                                                                                                                                                                                 | map(string)  |                []                 |    No    |
| aws_auth_accounts                      | List of account maps to add to the aws-auth configmap                                                                                                                                                                                                                              | map(string)  |                []                 |    No    |
| enable_irsa                            | Determines whether to create an OpenID Connect Provider for EKS to enable IRSA                                                                                                                                                                                                     |     bool     |               true                |    No    |
| openid_connect_audiences               | List of OpenID Connect audience client IDs to add to the IRSA provider                                                                                                                                                                                                             | list(string) |                []                 |    No    |
| custom_oidc_thumbprints                | Additional list of server certificate thumbprints for the OpenID Connect (OIDC) identity provider's server certificate(s)                                                                                                                                                          | list(string) |                []                 |    No    |

### Outputs
| Name                  | Description                                             | Sensitive |
|-----------------------|---------------------------------------------------------|-----------|
| cluster_id            | EKS cluster ID                                          | false     |
| cluster_version       | EKS cluster version                                     | false     |
| ami_id                | AMI ID used for worker EC2 instance node group          | false     |
| node_instance_profile | EC2 instance profile for EKS work node group            | false     |
| node_security_group   | security group for EKS work node group                  | false     |
| node_role_arn         | IAM role ARN for EKS work node group                    | false     |
| node_role_name        | IAM role name for EKS work node group                   | false     |
| node_asg_name         | EKS work node group name                                | false     |
| oidc_arn              | EKS cluster OpenID Connect (OIDC) identity provider ARN | false     |
| oidc_url              | EKS cluster OpenID Connect (OIDC) identity provider URL | false     |
| vpc_id                | EKS cluster VPC ID                                      | false     |
| private_subnets       | List of private subnets                                 | false     |
| database_subnets      | List of database subnets                                | false     |
