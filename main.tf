provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/28"
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.0.0/28"
}

resource "aws_security_group" "allow_default_port" {
  name        = "allow_default_port"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.main.id

   egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_default_port"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_default_port_ipv4" {
  security_group_id = aws_security_group.allow_default_port.id
  cidr_ipv4         = aws_vpc.main.cidr_block
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_default_port_ipv6" {
  security_group_id = aws_security_group.allow_default_port.id
  cidr_ipv6         = aws_vpc.main.ipv6_cidr_block
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_instance" "web1" {
  ami                       = data.aws_ami.ubuntu.id
  instance_type             = "t3.micro"
  subnet_id                 = aws_subnet.public_subnet.id
  security_groups           = aws_security_group.allow_default_port.id
  tags = {
    Name = "HelloWorld1"
  }
}

resource "aws_instance" "web2" {
  ami                       = data.aws_ami.ubuntu.id
  instance_type             = "t3.micro"
  subnet_id                 = aws_subnet.public_subnet.id
  security_groups           = aws_security_group.allow_default_port.id
  tags = {
    Name = "HelloWorld2"
  }
}

resource "aws_security_group" "load_balancer_sg" {
  name        = "load_balancer_sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.main.id 
  
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "load_balancer_sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "load_balancer_sg_ipv4" {
  security_group_id = aws_security_group.load_balancer_sg.id
  cidr_ipv4         = aws_vpc.main.cidr_block
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "load_balancer_sg_ipv6" {
  security_group_id = aws_security_group.load_balancer_sg.id
  cidr_ipv6         = aws_vpc.main.ipv6_cidr_block
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}


# Missed to attach the instance with the load_balancer
resource "aws_lb" "test" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = aws_security_group.load_balancer_sg.id
  subnets            = aws_subnet.public_subnet.id

  enable_deletion_protection = true

  tags = {
    Environment = "test"
  }
}

resource "aws_lb_target_group" "test" {
  name     = "tf-example-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.test.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:iam::187416307283:server-certificate/test_cert_rab3wuqwgja25ct3n4jdj2tzu4"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.test.arn
  }
}
