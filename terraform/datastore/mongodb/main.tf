# Pull remote state data from the VPC and app layer

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config {
    bucket = "terraform-state-ryanhartkopf"
    key = "vpc/terraform.tfstate"
    region = "us-east-1"
  }
}
data "terraform_remote_state" "app" {
  backend = "s3"
  config {
    bucket = "terraform-state-ryanhartkopf"
    key = "services/app/terraform.tfstate"
    region = "us-east-1"
  }
}

# The configuration for remote state will be filled in by Terragrunt

terraform {
  backend "s3" {}
}

# Configure AWS provider

provider "aws" {
  region = "${var.region}"
}
