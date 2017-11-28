output "mongo_static_ip" {
  value = "${var.mongo_static_ips[0]}"
}

output "security_group_id" {
  value = "${aws_security_group.mongodb.id}"
}
