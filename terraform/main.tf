# Define subnets for MongoDB replSet

resource "aws_subnet" "data" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "${var.aws_subnet_cidr_blocks_data[count.index]}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  count = "${length(var.aws_subnet_cidr_blocks_data)}"
  tags {
    Name = "${var.project_name}-data-${count.index}"
  }
}
