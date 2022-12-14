output "tf_state_bucket" {
  value = aws_s3_bucket.terraform_state_storage_s3.*.id
}

output "tf_dynamodb_table" {
  value = aws_dynamodb_table.terraform_state_lock.*.name
}