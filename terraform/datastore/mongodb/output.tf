output "mongo_dns" {
  value = "${aws_elb.mongodb.dns_name}"
}

output "security_group_id" {
  value = "${aws_security_group.mongodb.id}"
}
