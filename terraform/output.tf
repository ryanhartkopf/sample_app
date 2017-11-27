output "region" {
  value = "${var.region}"
}

output "vpc" {
  value = "${aws_vpc.main.id}"
}

output "build_subnet_id" {
  value = "${aws_subnet.app.0.id}"
}
