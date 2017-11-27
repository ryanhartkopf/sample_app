# Configure AWS provider

provider "aws" {
  region = "${var.region}"
}

terraform {
  backend "s3" {
    bucket         = "terraform-ryanhartkopf"
    key            = "vpc/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-ryanhartkopf"
  }
}

# Create VPC for application

resource "aws_vpc" "main" {
  cidr_block = "${var.aws_vpc_cidr_block}"
  tags {
    Name = "${var.project_name}"
  }
}

# Create internet gateway for outbound connections

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"
  tags {
    Name = "${aws_vpc.main.tags.Name}"
  }
}

# Allow traffic to internet
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.main.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.gw.id}"
}
