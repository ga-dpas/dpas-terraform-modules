# Live Examples to exercise this suite of Terraform Modules

## Usage
- Select the correct AWS credentials to use with sufficient privileges to spin up the infrastructure, e.g. `export AWS_PROFILE=admin`
- Create a backend to store terraform state if requires. There is an example provided under `examples/00_backend_int` that creates the s3 bucket to store terraform state and the dynamodb table to store terraform state lock.
- To create a full eks infrastructure on AWS platform, execute `examples/01_dpas_eks` module. Please note that the number in front, e.g. `00_ / 01_`, represents the correct order of execution to manage dependencies.
- Adjust some configuration params such as `owner`, `namespace`, `environment`, `region` and `terraform backend` - so they are unique to your organisation.

## Create your live repo

This repo provides terraform modules required to setup a DPAS processing EKS cluster on AWS platform.

## Create terraform backend

We store the current state of the infrastructure on an AWS S3 bucket to ensure terraform knows what infrastructure it
has created, even if something happens to the machine.

We also use a simple dynamodb table as a lock to ensure multiple people can't make a deployment at the same time.

To set up this infrastructure, you'll need to adjust the following local variables in `examples/00_backend_init/backend_init.tf`

| Variable      | Description                                                                     | Default            |
|:--------------|:--------------------------------------------------------------------------------|--------------------|
| `region`      | The AWS region to provision resources                                           | `"ap-southeast-2"` |
| `owner`       | The owner of the environment                                                    | `"ga"`             |
| `namespace`   | The name used for creation of backend resources like the terraform state bucket | `"dpas"`           |
| `environment` | The name of the environment - e.g. `dev`, `sandbox`, `prod`                     | `"sandbox"`        |
| `tags`        | Supply tags as per your organisation need                                       |                    |

The `namespace` and `environment` combination needs to be unique for your project. This is used for resource naming convention to support multiple environments in given AWS accounts.
Supply tags will be applied to all the resources provision by live repo. 

Run these commands in order to create the required infrastructure to store terraform state:

```shell script
  cd examples/00_backend_init
  terraform init
  terraform plan
  terraform apply
```

Terraform will create the required resources, at the end you'll see:

> `Apply complete!`


```properties
tf-state-bucket="${namespace}-${environment}-backend-tfstate"
dynamodb_table="${namespace}-${environment}-backend-terraform-lock"
```

Congratulations you're all setup and ready to build your first cluster!

## Creating your first cluster

Once you have created terraform backend, you can perform the following steps to setup a new DPAS cluster environment -

- Change directory to `examples/01_dpas_eks/`
- Adjust the following local variables in `data_providers.tf`

| Variable      | Description                                                                     | Default            |
|:--------------|:--------------------------------------------------------------------------------|--------------------|
| `region`      | The AWS region to provision resources                                           | `"ap-southeast-2"` |
| `owner`       | The owner of the environment                                                    | `"ga"`            |
| `namespace`   | The name used for creation of backend resources like the terraform state bucket | `"dpas"`           |
| `environment` | The name of the environment - e.g. `dev`, `sandbox`, `prod`                     | `"sandbox"`        |
| `tags`        | Supply tags as per your organisation need                                       |                    |
    
- This module optionally deploys karpenter and flux2 related AWS resources and helm release. You can turn it off by setting `enable_karpenter` and `enable_flux2` flags to `false` in `data_providers.tf` 
- Modify `main.tf`:
    - `bucket`: `<namespace>-<environment>-backend-tfstate`
    - `dynamodb_table`: `<namespace>-<environment>-backend-tflock`
    - `region` : `<region>`
- Run `terraform init` to initialize Terraform state tracking
- Run `terraform plan` to do a dry run and validate examples and interaction of modules
- Run `terraform apply` to spin up infrastructure -- can take upto 15-20 minutes
- Validate a fresh kubernetes cluster has been created by adding a new kubernetes context and getting clusterinfo

Congratulations you're all setup with DPAS EKS cluster for kubernetes workloads and applications.

To Destroy all terraform infrastructure run below command. 
```shell script
  cd examples/01_dpas_eks
  terraform init
  terraform destroy
```