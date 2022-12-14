output "tf_state_bucket" {
  value = module.backend_init.tf_state_bucket
}

output "tf_dynamodb_table" {
  value = module.backend_init.tf_dynamodb_table
}