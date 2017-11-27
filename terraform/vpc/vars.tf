terragrunt = {
  include {
    path = "${find_in_parent_folders()}"
  }
}

variable "project_name" {
  default = "sample"
}

variable "region" {
  default = "us-east-1"
}

variable "aws_amis" {
  default = {
    "us-east-1" = "ami-da05a4a0"
  }
}

variable "instance_types" {
  default = "t2.nano"
}

variable "aws_vpc_cidr_block" {
  default = "10.0.0.0/16"
}
