resource "aws_subnet" "mongodb" {
  vpc_id            = "${data.terraform_remote_state.vpc.vpc_id}"
  cidr_block        = "${var.aws_subnet_cidr_blocks[count.index]}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  count             = "${length(var.aws_subnet_cidr_blocks)}"

  tags {
    Name = "${data.terraform_remote_state.vpc.project_name}-mongodb-${count.index}"
  }
}

resource "aws_security_group" "mongodb-elb" {
  vpc_id      = "${data.terraform_remote_state.vpc.vpc_id}"
  name        = "${data.terraform_remote_state.vpc.project_name}-mongodb-elb"
  description = "Security group for ${data.terraform_remote_state.vpc.project_name} mongodb Elastic Load Balancer"
}

resource "aws_security_group_rule" "mongodb-elb-allow-27017-in" {
  security_group_id = "${aws_security_group.mongodb-elb.id}"

  type                     = "ingress"
  from_port                = 27017
  to_port                  = 27017
  protocol                 = "tcp"
  source_security_group_id = "${data.terraform_remote_state.app.security_group_id}"
  description              = "Allow traffic inbound from app instances"
}

resource "aws_security_group_rule" "mongodb-elb-allow-27017-out" {
  security_group_id = "${aws_security_group.mongodb-elb.id}"

  type                     = "egress"
  from_port                = 27017
  to_port                  = 27017
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.mongodb.id}"
  description              = "Allow traffic outbound to MongoDB instances"
}

resource "aws_security_group" "mongodb" {
  name        = "${data.terraform_remote_state.vpc.project_name}-mongodb"
  description = "Security group for ${data.terraform_remote_state.vpc.project_name} MongoDB instances"
  vpc_id      = "${data.terraform_remote_state.vpc.vpc_id}"
}

resource "aws_security_group_rule" "mongodb-allow-27017-in" {
  security_group_id = "${aws_security_group.mongodb.id}"

  type                     = "ingress"
  from_port                = 27017
  to_port                  = 27017
  protocol                 = "tcp"
  source_security_group_id = "${data.terraform_remote_state.app.security_group_id}"
  description              = "Allow traffic inbound from MongoDB ELB"
}

resource "aws_security_group_rule" "mongodb-allow-27017-internal" {
  security_group_id = "${aws_security_group.mongodb.id}"

  type                     = "ingress"
  from_port                = 27017
  to_port                  = 27017
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.mongodb.id}"
  description              = "Allow traffic between MongoDB instances"
}
resource "aws_security_group_rule" "mongodb-allow-27017-internal-out" {
  security_group_id = "${aws_security_group.mongodb.id}"

  type                     = "egress"
  from_port                = 27017
  to_port                  = 27017
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.mongodb.id}"
  description              = "Allow traffic between MongoDB instances"
}

resource "aws_security_group_rule" "mongodb-allow-all-out" {
  security_group_id = "${aws_security_group.mongodb.id}"

  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  description = "Allow all outbound access"
}
