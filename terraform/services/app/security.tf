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


