module "backend_label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.24.1"
  namespace  = var.namespace
  stage      = var.environment
  name       = "backend"
  attributes = var.attributes
  delimiter  = var.delimiter

  tags = merge(
    {
      owner       = var.owner
      namespace   = var.namespace
      environment = var.environment
    },
    var.tags
  )
}

# create S3 bucket to store the state file in
resource "aws_s3_bucket" "terraform_state_storage_s3" {
  bucket = "${module.backend_label.id}-tfstate"

  # Uncomment this to prevent unintended destruction of state
  # lifecycle {
  #   prevent_destroy = true
  # }

  tags = module.backend_label.tags
}

resource "aws_s3_bucket_versioning" "terraform_state_storage_s3" {
  bucket = aws_s3_bucket.terraform_state_storage_s3.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_storage_s3" {
  bucket = aws_s3_bucket.terraform_state_storage_s3.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state_storage_s3" {
  bucket = aws_s3_bucket.terraform_state_storage_s3.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# bucket-level - object ownership control
resource "aws_s3_bucket_ownership_controls" "terraform_state_storage_s3" {
  bucket = aws_s3_bucket.terraform_state_storage_s3.id

  rule {
    object_ownership = var.data_bucket_object_ownership
  }
}

# The terraform lock database resource
resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = "${module.backend_label.id}-tflock"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = module.backend_label.tags
}
