#####################
##  Configuration  ##
#####################

# Configure AWS provider - credentials are stored in ~/.aws/credentials

provider "aws" {
  region = "${var.region}"
}

# Create deploy public key for EC2 instances
resource "aws_key_pair" "deployer" {
  key_name   = "deployer"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDR7MkSkwOPdhKGEPZ3J9Lmph+PyoB9eG/ZpX+yj/KXKQLtmeXwRkQ//mgFjbYyl2u3WcztT2gY8Lxb3zEKi90lr0WFvuWQvx6r+i8v6mLwO3sxem+3srmGdYGJUvbD21pd/Mo2O6OB5+FgJy3VeqybJYYqFOOOLsKNrbOU9UyugWLpyqaB5YGndq67SpqMCLeqwy69Wvmu6gOvjPcnGOWjVxZe+3bff7ZfJnzu04qcKNFfBONxkCm4ss8euMTEY3wOPZqkx0LYjs67se/VPD6RFrq10tzPVBQqTDAfrsQc3TSimhJgZaNb7/cbNuolFSRHVTTwwbvFd0nKhwGcLLAv"
}

##################
##  Networking  ##
##################

# Create VPC for sample application

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags {
    Name = "sample"
  }
}

# Create internet gateway for outbound connections

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"
  tags {
    Name = "${aws_vpc.main.tags.Name}"
  }
}

# Define subnets for swarm nodes
resource "aws_subnet" "swarmA" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "10.0.1.0/24"
  availability_zone = "${var.region}a"
  tags {
    Name = "swarmA"
  }
}

resource "aws_subnet" "swarmB" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "10.0.2.0/24"
  availability_zone = "${var.region}b"
  tags {
    Name = "swarmB"
  }
}

# Define subnets for MongoDB replSet

resource "aws_subnet" "mongoA" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "10.0.3.0/24"
  availability_zone = "${var.region}a"
  tags {
    Name = "mongoA"
  }
}

resource "aws_subnet" "mongoB" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "10.0.4.0/24"
  availability_zone = "${var.region}b"
  tags {
    Name = "mongoB"
  }
}

#######################
##  Security Groups  ##
#######################

# Create security group for swarm nodes
resource "aws_security_group" "swarm-nodes" {
  name = "swarm-nodes"
  description = "Firewall rules for Docker Swarm nodes"
  vpc_id = "${aws_vpc.main.id}"
}

# Create security group for Elastic Load Balancer
resource "aws_security_group" "swarm-elb" {
  name = "swarm-elb"
  description = "Firewall rules for Elastic Load Balancer"
  vpc_id = "${aws_vpc.main.id}"
}

# Allow traffic from ELB to swarm nodes
resource "aws_security_group_rule" "swarm-nodes-allow-8080-in" {
  security_group_id = "${aws_security_group.swarm-nodes.id}"

  type = "ingress"
  from_port = 8080
  to_port = 8080
  protocol = "tcp"
  source_security_group_id = "${aws_security_group.swarm-elb.id}"
}

# Allow traffic from public web to ELB
resource "aws_security_group_rule" "swarm-elb-allow-80-in" {
  security_group_id = "${aws_security_group.swarm-elb.id}"

  type = "ingress"
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

#####################
##  EC2 Instances  ##
#####################

resource "aws_instance" "swarm-node" {
  instance_type = "t2.micro"
  ami           = "${lookup(var.aws_amis, var.region)}"
  key_name      = "${aws_key_pair.deployer.key_name}"
  subnet_id     = "${element(list("${aws_subnet.swarmA.id}", "${aws_subnet.swarmB.id}"), count.index)}"
  vpc_security_group_ids = ["${aws_security_group.swarm-nodes.id}"]
  root_block_device = {
    volume_type = "gp2"
    volume_size = 8
  }

  # Create 4 instance
  count = 4
}

######################
##  Load Balancers  ##
######################

resource "aws_elb" "swarm-elb" {
  name    = "swarm-elb"
  subnets = ["${aws_subnet.swarmA.id}", "${aws_subnet.swarmB.id}"]

  listener {
    instance_port     = 8080
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:8080/"
    interval            = 30
  }

  instances                 = ["${aws_instance.swarm-node.*.id}"]
  cross_zone_load_balancing = true
}

