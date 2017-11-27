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
  default = {
    "app"  = "t2.nano"
    "data" = "t2.micro"
  }
}

variable "aws_vpc_cidr_block" {
  default = "10.0.0.0/16"
}

variable "aws_subnet_cidr_blocks_app" {
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "aws_subnet_cidr_blocks_data" {
  default = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "jenkins_cidr" {
  default = "10.0.0.112/32"
}

data "aws_availability_zones" "available" {}
