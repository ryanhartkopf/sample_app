#####################
##  Configuration  ##
#####################

# Configure AWS provider - credentials are stored in ~/.aws/credentials

provider "aws" {
  region = "${var.region}"
}

terraform {
  backend "s3" {
    bucket = "terraform-ryanhartkopf"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}
    

# Create deploy public key for EC2 instances
resource "aws_key_pair" "deployer" {
  key_name   = "deployer"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDDbGy2Uwh8PwxVI/gQIieENxI9LXA4KvvCvwGI6//eIXLaDFAJODUbvelV3jumOsI/HhoXXQwIiv5qsaLmYVB3n3nVATy6ekPt5pKQigu+7fttVPE3BWCe84AiWGNd9CuG598yLlzv/IUSK7oYhHUaOo6YBiMQhQOdchWwd2xrWWUYTdnfUB7AfmuPeTf0G3ZA07pZuTmtjYrIPMTiwWg5sePJqnzc+onPHDoD5lhNIdNqfrUXzizuLZ4G4UFgiqDk1CejyOof3tj8NEdLgP9ANil8y17NKpTO1xBn8G2qSMMlna0RCEOpv7lAjLALYPkL0b2L1Y3V2oTxzaPUyfk9"
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

# Create security group for all swarm members
resource "aws_security_group" "swarm" {
  name = "swarm"
  description = "Firewall rules for Docker Swarm members"
  vpc_id = "${aws_vpc.main.id}"
}

# Create security group for swarm manager
resource "aws_security_group" "swarm-manager" {
  name = "swarm-manager"
  description = "Firewall rules for Docker Swarm manager"
  vpc_id = "${aws_vpc.main.id}"
}

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

# Allow traffic from swarm nodes to swarm manager
resource "aws_security_group_rule" "swarm-manager-allow-2376-in" {
  security_group_id = "${aws_security_group.swarm-manager.id}"

  type = "ingress"
  from_port = 2377
  to_port = 2377
  protocol = "tcp"
  source_security_group_id = "${aws_security_group.swarm-nodes.id}"
}

# Allow Docker traffic between swarm nodes
resource "aws_security_group_rule" "swarm-nodes-allow-7946-in-tcp" {
  security_group_id = "${aws_security_group.swarm-nodes.id}"

  type = "ingress"
  from_port = 7946
  to_port = 7946
  protocol = "tcp"
  source_security_group_id = "${aws_security_group.swarm-nodes.id}"
}
resource "aws_security_group_rule" "swarm-nodes-allow-7946-in-udp" {
  security_group_id = "${aws_security_group.swarm-nodes.id}"

  type = "ingress"
  from_port = 7946
  to_port = 7946
  protocol = "udp"
  source_security_group_id = "${aws_security_group.swarm-nodes.id}"
}

# Allow overlay network traffic between all swarm members
resource "aws_security_group_rule" "swarm-allow-4789-in-udp" {
  security_group_id = "${aws_security_group.swarm.id}"

  type = "ingress"
  from_port = 4789
  to_port = 4789
  protocol = "udp"
  source_security_group_id = "${aws_security_group.swarm.id}"
}

# Allow inbound SSH to swarm members from home base
resource "aws_security_group_rule" "swarm-allow-22-in" {
  security_group_id = "${aws_security_group.swarm.id}"

  type = "ingress"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = ["${var.jenkins_cidr}"]
}
  

#####################
##  EC2 Instances  ##
#####################

resource "aws_instance" "swarm-manager" {
  instance_type = "t2.micro"
  ami           = "${lookup(var.aws_amis, var.region)}"
  key_name      = "${aws_key_pair.deployer.key_name}"
  subnet_id     = "${element(list("${aws_subnet.swarmA.id}", "${aws_subnet.swarmB.id}"), count.index)}"
  vpc_security_group_ids = ["${aws_security_group.swarm-manager.id}", "${aws_security_group.swarm.id}"]
  root_block_device = {
    volume_type = "gp2"
    volume_size = 8
  }
  connection {
    user = "ubuntu"
    private_key = "${file("deployer")}"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install apt-transport-https ca-certificates",
      "sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D",
      "sudo sh -c 'echo \"deb https://apt.dockerproject.org/repo ubuntu-xenial main\" > /etc/apt/sources.list.d/docker.list'",
      "sudo apt-get update",
      "sudo apt-get install -y docker-engine",
      "sudo docker swarm init",
      "sudo docker swarm join-token --quiet worker > /home/ubuntu/token"
    ]
  }
  provisioner "file" {
    source = "proj"
    destination = "/home/ubuntu/"
  }
  tags = { 
    Name = "swarm-manager"
  }
}

resource "aws_instance" "swarm-node" {
  instance_type = "t2.micro"
  ami           = "${lookup(var.aws_amis, var.region)}"
  key_name      = "${aws_key_pair.deployer.key_name}"
  subnet_id     = "${element(list("${aws_subnet.swarmA.id}", "${aws_subnet.swarmB.id}"), count.index)}"
  vpc_security_group_ids = ["${aws_security_group.swarm-nodes.id}", "${aws_security_group.swarm.id}"]
  root_block_device = {
    volume_type = "gp2"
    volume_size = 8
  }

  # Create 4 instance
  count = 4

  connection {
    user = "ubuntu"
    private_key = "${file("deployer")}"
  }
  provisioner "file" {
    source = "key.pem"
    destination = "/home/ubuntu/key.pem"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install apt-transport-https ca-certificates",
      "sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D",
      "sudo sh -c 'echo \"deb https://apt.dockerproject.org/repo ubuntu-xenial main\" > /etc/apt/sources.list.d/docker.list'",
      "sudo apt-get update",
      "sudo apt-get install -y docker-engine",
      "sudo chmod 400 /home/ubuntu/test.pem",
      "sudo scp -o StrictHostKeyChecking=no -o NoHostAuthenticationForLocalhost=yes -o UserKnownHostsFile=/dev/null -i test.pem ubuntu@${aws_instance.swarm-manager.private_ip}:/home/ubuntu/token .",
      "sudo docker swarm join --token $(cat /home/ubuntu/token) ${aws_instance.swarm-manager.private_ip}:2377"
    ]
  }
  tags = { 
    Name = "swarm-node-${count.index}"
  }
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

