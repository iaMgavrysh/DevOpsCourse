provider "aws" {
  region = "eu-central-1"
}


data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "pub_sub" {
  vpc_id     = aws_vpc.main.id
  availability_zone = "eu-central-1a"
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "pub_sub"
  }
}
#resource "aws_subnet" "priv_sub" {
#  vpc_id  = aws_vpc.main.id
#  availability_zone = "eu-central-1a"
#  cidr_block = "10.0.2.0/24"
#  tags = {
#    Name = "priv_sub"
#  }
#}

resource "aws_route_table" "r" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "pub"
  }
}
#resource "aws_route_table" "r2" {
#  vpc_id = aws_vpc.main.id
# 
#  route {
#    cidr_block = "0.0.0.0/0"
#    gateway_id = aws_nat_gateway.nat_gateway.id
#}
#  tags = {
#    Name = "priv"
#  }
#}
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.pub_sub.id
  route_table_id = aws_route_table.r.id
}
#resource "aws_route_table_association" "b" {
#  subnet_id      = aws_subnet.priv_sub.id
#  route_table_id = aws_route_table.r2.id
#}
#resource "aws_eip" "eip" {
#  vpc = true
#}

#resource "aws_nat_gateway" "nat_gateway" {
#  allocation_id = aws_eip.eip.id
#  subnet_id = aws_subnet.pub_sub.id
#  tags = {
#    "Name" = "NatGateway"
#  }
#}
resource "aws_security_group" "bastion_ssh" {
  name        = "allow_ssh"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["x.x.x.x/32"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion_ssh"
  }
}
resource "aws_security_group" "allow_ssh_http" {
  name        = "allow_ssh_http"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["x.x.x.x/32"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh&http_private"
  }
}
resource "random_pet" "name" {}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.pub_sub.id
  vpc_security_group_ids = [aws_security_group.bastion_ssh.id]
  key_name               = "aws"
  tags = {
    Name = random_pet.name.id
  }
}
resource "aws_instance" "nginx" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.pub_sub.id
  user_data              = file( "startup_inst")
  vpc_security_group_ids = [aws_security_group.allow_ssh_http.id]
  key_name               = "aws"
  tags = {
    Name = "web_server"
  }
}