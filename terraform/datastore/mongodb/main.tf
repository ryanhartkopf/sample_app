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

# Define subnets for data nodes

resource "aws_subnet" "data" {
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"
  cidr_block = "${var.aws_subnet_cidr_blocks[count.index]}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  count = "${length(var.aws_subnet_cidr_blocks)}"

  tags {
    Name = "${data.terraform_remote_state.vpc.project_name}-data-${count.index}"
  }
}

# Create security group for data instances

resource "aws_security_group" "data" {
  name = "${data.terraform_remote_state.vpc.project_name}-data"
  description = "Firewall rules for ${data.terraform_remote_state.vpc.project_name} data instances"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"
}

# Allow web traffic to data instances from app

resource "aws_security_group_rule" "data-allow-27017-in-app" {
  security_group_id = "${aws_security_group.data.id}"

  type = "ingress"
  from_port = 27017
  to_port = 27017
  protocol = "tcp"
  source_security_group_id = "${data.terraform_remote_state.app.security_group_id}"
}

# Allow web traffic between data instances within security group

resource "aws_security_group_rule" "data-allow-27017-internal" {
  security_group_id = "${aws_security_group.data.id}"

  type = "ingress"
  from_port = 27017
  to_port = 27017
  protocol = "tcp"
  source_security_group_id = "${aws_security_group.data.id}"
}
resource "aws_security_group_rule" "data-allow-27017-internal-out" {
  security_group_id = "${aws_security_group.data.id}"

  type = "egress"
  from_port = 27017
  to_port = 27017
  protocol = "tcp"
  source_security_group_id = "${aws_security_group.data.id}"
}

# Create persistent EBS volume to hold our data
resource "aws_ebs_volume" "mongoA" {
  availability_zone = "${element("${aws_subnet.data.*.availability_zone}", count.index)}"
  encrypted         = true
  type              = "gp2"
  size              = 8

  tags {
    Name = "mongoA"
  }

  # This resource is persistent and should never be deleted by Terraform
  lifecycle {
    prevent_destroy = true
  }
}

# Create persistent IP address so Packer can pull its IP from the remote state

resource "aws_network_interface" "test" {
  subnet_id       = "${element("${aws_subnet.data.*.id}", count.index)}"
  private_ips     = ["${var.mongo_static_ips[count.index]}"]
  security_groups = ["${aws_security_group.data.id}"]
}

# Configure Auto-Scaling Group and launch it

resource "aws_launch_configuration" "data" {
  image_id             = "${var.source_ami}"
  instance_type        = "${var.instance_type}"
  iam_instance_profile = "AttachEBSVolume"
  key_name             = "deployer"
  user_data            = "${file("user_data.sh")}"
  security_groups      = ["${aws_security_group.data.id}"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "data" {
  # interpolate the LC into the ASG name so it always forces an update
  name = "asg-data-${aws_launch_configuration.data.name}"

  vpc_zone_identifier       = ["${aws_subnet.data.*.id}"]
  max_size                  = 1
  min_size                  = 1
  desired_capacity          = 1
  health_check_type         = "EC2"
  launch_configuration      = "${aws_launch_configuration.data.name}"

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "${data.terraform_remote_state.vpc.project_name}-data"
    propagate_at_launch = true
  }
}
