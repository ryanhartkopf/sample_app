# Create Elastic IP for Jenkins instance

resource "aws_eip" "jenkins" {
  vpc      = true
}

# Spin up Jenkins EC2 instance

resource "aws_instance" "jenkins" {
  subnet_id              = "${aws_subnet.admin.id}"
  ami                    = "${var.source_ami}"
  instance_type          = "${var.instance_type}"
  vpc_security_group_ids = ["${aws_security_group.jenkins.id}"]
  key_name               = "deployer"
  iam_instance_profile   = "TerraformPowerUser"

  tags {
    Name = "jenkins"
  }
}

# Associate Elastic IP with Jenkins instance
resource "aws_eip_association" "jenkins" {
  instance_id   = "${aws_instance.jenkins.id}"
  allocation_id = "${aws_eip.jenkins.id}"
}
