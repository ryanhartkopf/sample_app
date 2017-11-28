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


