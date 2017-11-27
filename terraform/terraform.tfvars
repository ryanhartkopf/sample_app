terragrunt = {
  remote_state {
    backend = "s3"
    config {
      bucket         = "terraform-state-wvoQVbzt"
      key            = "${path_relative_to_include()}/terraform.tfstate"
      region         = "us-east-1"
      encrypt        = true
      dynamodb_table = "terragrunt-lock-table-alnr48bv"
    }
  }
}
