variable "region" {
  default = "us-east-1"
}

variable "source_ami" {
  default = "ami-da05a4a0"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "aws_subnet_cidr_blocks" {
  default = ["10.0.3.0/24"]
}

data "aws_availability_zones" "available" {}
