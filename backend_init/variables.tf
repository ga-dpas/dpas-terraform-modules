variable "namespace" {
  description = "The name used for creation of backend resources like the terraform state bucket"
  default     = "dea-odc"
}

variable "owner" {
  description = "The owner of the environment"
  default     = "dea"
}

variable "environment" {
  description = "The name of the environment - e.g. dev, stage, prod"
  default     = "dev"
}

variable "delimiter" {
  type        = string
  default     = "-"
  description = "Delimiter to be used between `namespace`, `stage`, `name` and `attributes`"
}

variable "attributes" {
  type        = list(string)
  default     = []
  description = "Additional attributes (e.g. `region`)"
}

variable "bucket_object_ownership" {
  type        = string
  default     = "BucketOwnerEnforced"
  description = "Specifies the S3 object ownership control. Expected value - `ObjectWriter`, `BucketOwnerPreferred`, or 'BucketOwnerEnforced'"
}

variable "tags" {
  type        = map(string)
  description = "Additional tags (e.g. `map('StackName','XYZ')`"
  default     = {}
}