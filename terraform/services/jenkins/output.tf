output "jenkins_ip" {
  value = "${aws_instance.jenkins.public_ip}"
}

output "graylog_ip" {
  value = "${aws_instance.graylog.public_ip}"
}

