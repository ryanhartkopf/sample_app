output "project_name" {
  value = "${var.project_name}"
}

output "region" {
  value = "${var.region}"
}

output "instance_types" {
  value = "${var.instance_types}"
}

output "aws_vpc_cidr_block" {
  value = "${var.aws_vpc_cidr_block}"
}

output "vpc_id" {
  value = "${aws_vpc.main.id}"
}
