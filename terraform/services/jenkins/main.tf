# Pull remote state data from the VPC

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config {
    bucket = "terraform-state-ryanhartkopf"
    key = "vpc/terraform.tfstate"    
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

# Define subnets for admin servers

resource "aws_subnet" "admin" {
  vpc_id            = "${data.terraform_remote_state.vpc.vpc_id}"
  cidr_block        = "${var.aws_subnet_cidr_blocks[count.index]}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  count             = "${length(var.aws_subnet_cidr_blocks)}"

  tags {
    Name = "${data.terraform_remote_state.vpc.project_name}-admin-${count.index}"
  }
}

# Configure security groups

resource "aws_security_group" "jenkins" {
  vpc_id      = "${data.terraform_remote_state.vpc.vpc_id}"
  name        = "jenkins"
  description = "Firewall rules for Jenkins instance"
}

resource "aws_security_group_rule" "jenkins-allow-22-in" {
  security_group_id = "${aws_security_group.jenkins.id}"

  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["${var.office_ip}"]
  description = "SSH access to Jenkins instance from office"
}

resource "aws_security_group_rule" "jenkins-allow-8080-in" {
  security_group_id = "${aws_security_group.jenkins.id}"

  type        = "ingress"
  from_port   = 8080
  to_port     = 8080
  protocol    = "tcp"
  cidr_blocks = ["${var.office_ip}"]
  description = "Jenkins web access from office"
}

resource "aws_security_group_rule" "jenkins-allow-8080-in-gh1" {
  security_group_id = "${aws_security_group.jenkins.id}"

  type        = "ingress"
  from_port   = 8080
  to_port     = 8080
  protocol    = "tcp"
  cidr_blocks = ["192.30.252.0/22"]
  description = "Allow access for GitHub webhooks"
}

resource "aws_security_group_rule" "jenkins-allow-8080-in-gh2" {
  security_group_id = "${aws_security_group.jenkins.id}"

  type        = "ingress"
  from_port   = 8080
  to_port     = 8080
  protocol    = "tcp"
  cidr_blocks = ["185.199.108.0/22"]
  description = "Allow access for GitHub webhooks"
}

# Create Elastic IP for Jenkins instance

resource "aws_eip" "jenkins" {
  vpc      = true
}

# Spin up Jenkins EC2 instance

resource "aws_instance" "jenkins" {
  subnet_id              = "${aws_subnet.admin.id}"
  ami                    = "${var.source_ami}"
  instance_type          = "${var.instance_type}"
  vpc_security_group_ids = ["${aws_security_group.jenkins.id}"]
  key_name               = "deployer"

  tags {
    Name = "jenkins"
  }
}

# Associate Elastic IP with Jenkins instance
resource "aws_eip_association" "jenkins" {
  instance_id   = "${aws_instance.jenkins.id}"
  allocation_id = "${aws_eip.jenkins.id}"
}
