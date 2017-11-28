# Define subnets for admin servers

resource "aws_subnet" "admin" {
  vpc_id            = "${data.terraform_remote_state.vpc.vpc_id}"
  cidr_block        = "${var.aws_subnet_cidr_blocks[count.index]}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  count             = "${length(var.aws_subnet_cidr_blocks)}"

  tags {
    Name = "${data.terraform_remote_state.vpc.project_name}-admin-${count.index}"
  }
}

# Configure security group for Jenkins

resource "aws_security_group" "jenkins" {
  vpc_id      = "${data.terraform_remote_state.vpc.vpc_id}"
  name        = "jenkins"
  description = "Firewall rules for Jenkins instance"
}

resource "aws_security_group_rule" "jenkins-allow-22-in" {
  security_group_id = "${aws_security_group.jenkins.id}"

  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["${var.office_ip}"]
  description = "SSH access to Jenkins instance from office"
}

resource "aws_security_group_rule" "jenkins-allow-8080-in" {
  security_group_id = "${aws_security_group.jenkins.id}"

  type        = "ingress"
  from_port   = 8080
  to_port     = 8080
  protocol    = "tcp"
  cidr_blocks = ["${var.office_ip}"]
  description = "Jenkins web access from office"
}

resource "aws_security_group_rule" "jenkins-allow-8080-in-gh1" {
  security_group_id = "${aws_security_group.jenkins.id}"

  type        = "ingress"
  from_port   = 8080
  to_port     = 8080
  protocol    = "tcp"
  cidr_blocks = ["192.30.252.0/22"]
  description = "Allow access for GitHub webhooks"
}

resource "aws_security_group_rule" "jenkins-allow-8080-in-gh2" {
  security_group_id = "${aws_security_group.jenkins.id}"

  type        = "ingress"
  from_port   = 8080
  to_port     = 8080
  protocol    = "tcp"
  cidr_blocks = ["185.199.108.0/22"]
  description = "Allow access for GitHub webhooks"
}

resource "aws_security_group_rule" "jenkins-allow-all-out" {
  security_group_id = "${aws_security_group.jenkins.id}"

  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  description = "Allow all outbound access"
}

# Configure security group for Graylog

resource "aws_security_group" "graylog" {
  vpc_id      = "${data.terraform_remote_state.vpc.vpc_id}"
  name        = "graylog"
  description = "Firewall rules for Graylog instance"
}

resource "aws_security_group_rule" "graylog-allow-22-in" {
  security_group_id = "${aws_security_group.graylog.id}"

  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["${var.office_ip}"]
  description = "SSH access to Graylog instance from office"
}

resource "aws_security_group_rule" "graylog-allow-514-in-app" {
  security_group_id = "${aws_security_group.graylog.id}"

  type        = "ingress"
  from_port   = 514
  to_port     = 514
  protocol    = "tcp"
  source_security_group_id = "${data.terraform_remote_state.app.security_group_id}"
  description = "Graylog log traffic from app instances"
}

resource "aws_security_group_rule" "graylog-allow-514-in-data" {
  security_group_id = "${aws_security_group.graylog.id}"

  type        = "ingress"
  from_port   = 514
  to_port     = 514
  protocol    = "tcp"
  source_security_group_id = "${data.terraform_remote_state.data.security_group_id}"
  description = "Graylog log traffic from data instances"
}

resource "aws_security_group_rule" "graylog-allow-9000-in" {
  security_group_id = "${aws_security_group.graylog.id}"

  type        = "ingress"
  from_port   = 9000
  to_port     = 9000
  protocol    = "tcp"
  cidr_blocks = ["${var.office_ip}"]
  description = "Graylog web access from office"
}

resource "aws_security_group_rule" "graylog-allow-all-out" {
  security_group_id = "${aws_security_group.graylog.id}"

  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  description = "Allow all outbound access"
}

