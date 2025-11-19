terraform {
  backend "s3" {
    bucket       = "dpas-sandbox-backend-tfstate"
    key          = "dpas_eks_terraform.tfstate"
    region       = "ap-southeast-2"
    use_lockfile = true
    encrypt      = true
  }

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.10.0"
    }
  }
}
