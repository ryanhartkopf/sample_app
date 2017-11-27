# Configure AWS provider

provider "aws" {
  region = "${var.region}"
}

# The configuration for remote state will be filled in by Terragrunt

terraform {
  backend "s3" {}
}

# Pull remote state data from the VPC

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config {
    bucket = "terraform-ryanhartkopf"
    key = "vpc/terraform.tfstate"    
    region = "us-east-1"
  }
}

# Define subnets for admin servers

resource "aws_subnet" "admin" {
  vpc_id            = "${data.terraform_remote_state.vpc.vpc_id}"
  cidr_block        = "${var.aws_subnet_cidr_blocks[count.index]}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  count             = "${length(var.aws_subnet_cidr_blocks)}"

  tags {
    Name = "${data.terraform_remote_state.vpc.project_name}-app-${count.index}"
  }
}

# Create Jenkins security group

resource "aws_security_group" "jenkins" {
  vpc_id      = "${data.terraform_remote_state.vpc.vpc_id}"
  name        = "${data.terraform_remote_state.vpc.project_name}-app-elb"
  description = "Firewall rules for ${data.terraform_remote_state.vpc.project_name} Elastic Load Balancer"
}

# Allow access to Jenkins from home office
resource "aws_security_group_rule" "app-elb-allow-8080-in" {
  security_group_id = "${aws_security_group.app-elb.id}"

  type        = "ingress"
  from_port   = 8080
  to_port     = 8080
  protocol    = "tcp"
  cidr_blocks = ["75.128.253.63/32"]
}

# Spin up Jenkins EC2 instance

resource "aws_instance" "jenkins" {
  subnet_id       = "${aws_subnet.admin.id}"
  ami             = "${var.source_ami}"
  instance_type   = "${var.instance_type}"
  security_groups = ["${aws_security_group.jenkins.id}"]
  key_name        = "deployer"

  tags {
    Name = "jenkins"
  }
}

# Create Elastic IP for Jenkins instance

resource "aws_eip" "jenkins" {
  instance = "${aws_instance.jenkins.id}"
  vpc      = true
}
