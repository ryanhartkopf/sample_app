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
  security_groups = ["${aws_security_group.app.id}"]

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

