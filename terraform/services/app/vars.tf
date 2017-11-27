variable "source_ami" {}

variable "instance_type" {
  default = "t2.nano"
}

variable "aws_subnet_cidr_blocks" {
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

data "aws_availability_zones" "available" {}
