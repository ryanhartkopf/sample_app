#####################
##  Configuration  ##
#####################

# Configure AWS provider - credentials are stored in ~/.aws/credentials

provider "aws" {
  region = "${var.region}"
}

terraform {
  backend "s3" {
    bucket = "terraform-ryanhartkopf"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}
    

# Create deploy public key for EC2 instances
#resource "aws_key_pair" "deployer" {
#  key_name   = "deployer"
#  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDDbGy2Uwh8PwxVI/gQIieENxI9LXA4KvvCvwGI6//eIXLaDFAJODUbvelV3jumOsI/HhoXXQwIiv5qsaLmYVB3n3nVATy6ekPt5pKQigu+7fttVPE3BWCe84AiWGNd9CuG598yLlzv/IUSK7oYhHUaOo6YBiMQhQOdchWwd2xrWWUYTdnfUB7AfmuPeTf0G3ZA07pZuTmtjYrIPMTiwWg5sePJqnzc+onPHDoD5lhNIdNqfrUXzizuLZ4G4UFgiqDk1CejyOof3tj8NEdLgP9ANil8y17NKpTO1xBn8G2qSMMlna0RCEOpv7lAjLALYPkL0b2L1Y3V2oTxzaPUyfk9"
#}

##################
##  Networking  ##
##################

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

# Define subnets for app nodes
resource "aws_subnet" "app" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "${var.aws_subnet_cidr_blocks_app[count.index]}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  count = "${length(var.aws_subnet_cidr_blocks_app)}"
  tags {
    Name = "${var.project_name}-app-${count.index}"
  }
}

# Define subnets for MongoDB replSet

resource "aws_subnet" "data" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "${var.aws_subnet_cidr_blocks_data[count.index]}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  count = "${length(var.aws_subnet_cidr_blocks_data)}"
  tags {
    Name = "${var.project_name}-data-${count.index}"
  }
}

#######################
##  Security Groups  ##
#######################

# Create security group for app instances
resource "aws_security_group" "app" {
  name = "${var.project_name}-app"
  description = "Firewall rules for ${var.project_name} app instances"
  vpc_id = "${aws_vpc.main.id}"
}

# Create security group for Elastic Load Balancer
resource "aws_security_group" "app-elb" {
  name = "${var.project_name}-app-elb"
  description = "Firewall rules for ${var.project_name} Elastic Load Balancer"
  vpc_id = "${aws_vpc.main.id}"
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

# Allow traffic to ELB from public internet
resource "aws_security_group_rule" "app-elb-allow-80-in" {
  security_group_id = "${aws_security_group.app-elb.id}"

  type = "ingress"
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

#####################
##  EC2 Instances  ##
#####################

# Configure app ASG and create it
resource "aws_launch_configuration" "app" {
  name     = "${var.project_name}-app-asg-config"
  image_id = "${lookup(var.aws_amis, var.region)}"
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

resource "aws_autoscaling_attachment" "app" {
  autoscaling_group_name = "${aws_autoscaling_group.app.id}"
  elb                    = "${aws_elb.app.id}"
}
