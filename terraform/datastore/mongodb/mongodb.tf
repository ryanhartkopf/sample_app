# Create persistent EBS volume to hold our data
resource "aws_ebs_volume" "mongoA" {
  availability_zone = "${element("${aws_subnet.mongodb.*.availability_zone}", count.index)}"
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

# Create ELB

resource "aws_elb" "mongodb" {
  name            = "${data.terraform_remote_state.vpc.project_name}-mongodb-elb"
  subnets         = ["${aws_subnet.mongodb.*.id}"]
  security_groups = ["${aws_security_group.mongodb-elb.id}"]
  internal        = true

  listener {
    instance_port     = 27017
    instance_protocol = "tcp"
    lb_port           = 27017
    lb_protocol       = "tcp"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:27017"
    interval            = 30
  }
}

# Configure Auto-Scaling Group, launch it, and attach to ELB

resource "aws_launch_configuration" "mongodb" {
  image_id             = "${var.source_ami}"
  instance_type        = "${var.instance_type}"
  iam_instance_profile = "AttachEBSVolume"
  key_name             = "deployer"
  user_data            = "${file("user_data.sh")}"
  security_groups      = ["${aws_security_group.mongodb.id}"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "mongodb" {
  # interpolate the LC into the ASG name so it always forces an update
  name = "asg-mongodb-${aws_launch_configuration.mongodb.name}"

  vpc_zone_identifier       = ["${aws_subnet.mongodb.*.id}"]
  max_size                  = 1
  min_size                  = 1
  desired_capacity          = 1
  wait_for_elb_capacity     = 1
  health_check_type         = "ELB"
  launch_configuration      = "${aws_launch_configuration.mongodb.name}"

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "${data.terraform_remote_state.vpc.project_name}-mongodb"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_attachment" "mongodb" {
  autoscaling_group_name = "${aws_autoscaling_group.mongodb.id}"
  elb                    = "${aws_elb.mongodb.id}"
}
