# Create Elastic IP for Graylog instance

resource "aws_eip" "graylog" {
  vpc      = true
}

# Spin up Graylog EC2 instance

resource "aws_instance" "graylog" {
  subnet_id              = "${aws_subnet.admin.id}"
  ami                    = "${var.source_ami}"
  instance_type          = "t2.medium"
  vpc_security_group_ids = ["${aws_security_group.graylog.id}"]
  key_name               = "deployer"

  tags {
    Name = "graylog"
  }
}

# Associate Elastic IP with Graylog instance
resource "aws_eip_association" "graylog" {
  instance_id   = "${aws_instance.graylog.id}"
  allocation_id = "${aws_eip.graylog.id}"
}

# Create EBS volume for log data and attach to instance
resource "aws_ebs_volume" "graylog1" {
  availability_zone = "${aws_instance.graylog.availability_zone}"
  size = 10

  tags {
    Name = "graylog1"
  }
}
resource "aws_volume_attachment" "graylog1" {
  device_name = "/dev/sdf"
  volume_id   = "${aws_ebs_volume.graylog1.id}"
  instance_id = "${aws_instance.graylog.id}"
}
