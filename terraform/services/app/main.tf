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

# Define subnets for app nodes

resource "aws_subnet" "app" {
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"
  cidr_block = "${var.aws_subnet_cidr_blocks[count.index]}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  count = "${length(var.aws_subnet_cidr_blocks)}"

  tags {
    Name = "${data.terraform_remote_state.vpc.project_name}-app-${count.index}"
  }
}

# Create security group for ELB

resource "aws_security_group" "app-elb" {
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"
  name = "${data.terraform_remote_state.vpc.project_name}-app-elb"
  description = "Firewall rules for ${data.terraform_remote_state.vpc.project_name} Elastic Load Balancer"
}

# Create security group for app instances
resource "aws_security_group" "app" {
  name = "${data.terraform_remote_state.vpc.project_name}-app"
  description = "Firewall rules for ${data.terraform_remote_state.vpc.project_name} app instances"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"
}

# Allow traffic to ELB from public internet
resource "aws_security_group_rule" "app-elb-allow-80-in" {
  security_group_id = "${aws_security_group.app-elb.id}"

  type = "ingress"
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

# Allow web traffic to app instances from ELB
resource "aws_security_group_rule" "app-allow-8080-in" {
  security_group_id = "${aws_security_group.app.id}"

  type = "ingress"
  from_port = 8080
  to_port = 8080
  protocol = "tcp"
  source_security_group_id = "${aws_security_group.app-elb.id}"
}

# Create ELB

resource "aws_elb" "app" {
  name    = "${data.terraform_remote_state.vpc.project_name}-app-elb"
  subnets = ["${aws_subnet.app.*.id}"]

  listener {
    instance_port     = 8080
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:8080/"
    interval            = 30
  }

  cross_zone_load_balancing = true
}

# Configure Auto-Scaling Group, launch it, and attach to ELB

resource "aws_launch_configuration" "app" {
  image_id        = "${var.source_ami}"
  instance_type   = "${var.instance_type}"
  security_groups = ["${aws_security_group.data.id}"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "app" {
  # interpolate the LC into the ASG name so it always forces an update
  name = "asg-app-${aws_launch_configuration.app.name}"

  vpc_zone_identifier       = ["${aws_subnet.app.*.id}"]
  max_size                  = 8
  min_size                  = 2
  desired_capacity          = 2
  wait_for_elb_capacity     = 2
  health_check_grace_period = 300
  health_check_type         = "ELB"
  launch_configuration      = "${aws_launch_configuration.app.name}"

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "${data.terraform_remote_state.vpc.project_name}-app"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_attachment" "app" {
  autoscaling_group_name = "${aws_autoscaling_group.app.id}"
  elb                    = "${aws_elb.app.id}"
}
