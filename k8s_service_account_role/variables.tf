variable "owner" {
  type        = string
  description = "The owner of the owner - e.g. ga"
}

variable "namespace" {
  type        = string
  description = "The unique namespace for the environment, which could be branch abbreviation e.g. dpas"
}

variable "environment" {
  type        = string
  description = "The name of the environment - e.g. dev, stage, prod"
}

variable "oidc_arn" {
  description = "The arn of the OpenId connect provider associated with this cluster"
}

variable "oidc_url" {
  description = "The url of the OpenId connect provider associated with this cluster"
}

variable "service_account_role" {
  type        = map(any)
  description = "Specify custom IAM roles that can be used by pods on the k8s cluster"
  # service_account_role = {
  #     name  = "foo"
  #     service_account_namespace = "foo-sa"
  #     service_account_name = "foo-sa"    # put "*" to scope a role to an entire namespace
  #     policy = <<-EOF
  #       IAMPolicyDocument
  #       WithIdents
  #     EOF
  # }
}

variable "tags" {
  type        = map(string)
  description = "Additional tags (e.g. `map('StackName','XYZ')`"
  default     = {}
}