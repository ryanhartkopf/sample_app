variable "region" {
  default = "us-east-1"
}

variable "aws_amis" {
  default = {
    "us-east-1" = "ami-da05a4a0"
  }
}

variable "jenkins_cidr" {
  default = "10.0.0.112/32"
}
