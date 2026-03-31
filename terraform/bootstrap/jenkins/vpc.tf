resource "aws_vpc" "jenkins" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-jenkins-vpc"
  }
}

resource "aws_subnet" "jenkins_public" {
  vpc_id                  = aws_vpc.jenkins.id
  cidr_block              = "10.10.1.0/24"
  map_public_ip_on_launch = true

  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${var.project_name}-jenkins-subnet"
  }
}

resource "aws_internet_gateway" "jenkins" {
  vpc_id = aws_vpc.jenkins.id

  tags = {
    Name = "${var.project_name}-jenkins-igw"
  }
}

resource "aws_route_table" "jenkins" {
  vpc_id = aws_vpc.jenkins.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.jenkins.id
  }
}

resource "aws_route_table_association" "jenkins" {
  subnet_id      = aws_subnet.jenkins_public.id
  route_table_id = aws_route_table.jenkins.id
}
