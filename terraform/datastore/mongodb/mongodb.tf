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

# Create persistent IP address so Packer can pull its IP from the remote state

resource "aws_network_interface" "mongoA" {
  subnet_id       = "${element("${aws_subnet.mongodb.*.id}", count.index)}"
  private_ips     = ["${var.mongo_static_ips[count.index]}"]
  security_groups = ["${aws_security_group.mongodb.id}"]
}

# Configure Auto-Scaling Group and launch it

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
  health_check_type         = "EC2"
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

