# Define subnets for mongodb

resource "aws_subnet" "mongodb" {
  vpc_id            = "${data.terraform_remote_state.vpc.vpc_id}"
  cidr_block        = "${var.aws_subnet_cidr_blocks[count.index]}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  count             = "${length(var.aws_subnet_cidr_blocks)}"

  tags {
    Name = "${data.terraform_remote_state.vpc.project_name}-mongodb-${count.index}"
  }
}

# Create security group for data instances

resource "aws_security_group" "mongodb" {
  name        = "${data.terraform_remote_state.vpc.project_name}-mongodb"
  description = "Firewall rules for ${data.terraform_remote_state.vpc.project_name} mongodb instances"
  vpc_id      = "${data.terraform_remote_state.vpc.vpc_id}"
}

# Allow web traffic to mongodb instances from app

resource "aws_security_group_rule" "mongodb-allow-27017-in-app" {
  security_group_id = "${aws_security_group.mongodb.id}"

  type                     = "ingress"
  from_port                = 27017
  to_port                  = 27017
  protocol                 = "tcp"
  source_security_group_id = "${data.terraform_remote_state.app.security_group_id}"
}

# Allow web traffic between mongodb instances within security group

resource "aws_security_group_rule" "mongodb-allow-27017-internal" {
  security_group_id = "${aws_security_group.mongodb.id}"

  type                     = "ingress"
  from_port                = 27017
  to_port                  = 27017
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.mongodb.id}"
}
resource "aws_security_group_rule" "mongodb-allow-27017-internal-out" {
  security_group_id = "${aws_security_group.mongodb.id}"

  type                     = "egress"
  from_port                = 27017
  to_port                  = 27017
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.mongodb.id}"
}


