# Configure AWS provider

provider "aws" {
  region = "${var.region}"
}

# The configuration for remote state will be filled in by Terragrunt

terraform {
  backend "s3" {}
}

# Define subnets for app nodes

resource "aws_subnet" "app" {
  vpc_id = "${var.vpc_id}"
  cidr_block = "${var.aws_subnet_cidr_blocks_app[count.index]}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  count = "${length(var.aws_subnet_cidr_blocks_app)}"

  tags {
    Name = "${var.project_name}-app-${count.index}"
  }
}

# Create security group for ELB

resource "aws_security_group" "app-elb" {
  vpc_id = "${var.vpc_id}"
  name = "${var.project_name}-app-elb"
  description = "Firewall rules for ${var.project_name} Elastic Load Balancer"
}

# Create security group for app instances
resource "aws_security_group" "app" {
  name = "${var.project_name}-app"
  description = "Firewall rules for ${var.project_name} app instances"
  vpc_id = "${var.vpc_id}"
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
  name    = "${var.project_name}-app-elb"
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
  name     = "${var.project_name}-app-asg-config"
  image_id = "${var.source_ami}"
  instance_type = "${lookup(var.instance_types, "app")}"
}

resource "aws_autoscaling_group" "app" {
  vpc_zone_identifier       = ["${aws_subnet.app.*.id}"]
  name                      = "${var.project_name}-app-asg"
  max_size                  = 8
  min_size                  = 2
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 4
  force_delete              = true
  launch_configuration      = "${aws_launch_configuration.app.name}"

  tag {
    key                 = "Name"
    value               = "${var.project_name}-app"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_attachment" "app" {
  autoscaling_group_name = "${aws_autoscaling_group.app.id}"
  elb                    = "${aws_elb.app.id}"
}
