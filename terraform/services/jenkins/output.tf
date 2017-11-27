output "jenkins_ip" {
  value = "${aws_instance.jenkins.private_ip}"
}

output "admin_subnet_id" {
  value = "${aws_subnet.admin.id}"
}
