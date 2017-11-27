output "jenkins_ip" {
  value = "${aws_instance.jenkins.private_ip}"
}
