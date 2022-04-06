terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "eu-central-1"
}

resource "aws_vpc" "test" {
  cidr_block = "10.0.0.0/24"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = var.tags
}

resource "aws_subnet" "test" {
  vpc_id     = aws_vpc.test.id
  cidr_block = "10.0.0.0/28"
  availability_zone = "eu-central-1a"

  tags = var.tags
}

resource "aws_subnet" "test2" {
  vpc_id     = aws_vpc.test.id
  cidr_block = "10.0.0.16/28"
  availability_zone = "eu-central-1b"

  tags = var.tags
}

resource "aws_route53_zone" "test" {
  name = "example.com"

  vpc {
    vpc_id = aws_vpc.test.id
  }
  tags = var.tags
}

resource "aws_key_pair" "test" {
  key_name   = "instance_key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCh/24Sz/go0Q52ubE3XBbHs4vOdeEAhYkamJnEspb1mtC7n9pWZJuYxxHD2s4J4e5gkpZapKGznFfPaSMtDhPwsZAmtY/heiwLTkwhGAnk+ldlQf0WM/S/OY7oxAGmH5oCYuZ7AjSxgPIO+bIgVsBDMv6eT+qD33BYiz3tg9u06RCktSnPSldYtNyIgfY3611aaLqNy03joXJHTWxYbNjfaPct46lx4DSlZlO5MlJoP6zVidsk92UtC2FElwoIvof8zuh8p71h7Tj7W9t8pNLBZwuErLS9fIS+CW3Gjs1wca+H9eXPxmhu9e/hUsy9wBjV+CwbCWExKVEgvGn0ScDaaloFHZGrx/sXGnOhT/GCt04JBfdhBtY5eZqcQ65NTcdiNIlFVYebBqDjUiCecPyOr6jICQl8C3hhsn9EJge04lht4rw2504aDtU/UMpxBkg3sE3TLYyrU4PoK3rs5kTXooDZcWFY1OjvolHupaes5wnCQ9L5arJ7pLxDDu0plcE= alakimov@C6208"
}

resource "aws_security_group" "test" {
  name        = "SG"
  vpc_id      = aws_vpc.test.id
  //count = var.enable_standalone_ec2 ? 1 : 0

  ingress {
    description      = "http"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "https"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["188.243.183.0/24"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = var.tags
}

# resource "aws_network_interface" "test" {
#   subnet_id   = aws_subnet.test.id
#   private_ips = ["10.0.0.5"]

#   tags = var.tags
# }

resource "aws_instance" "test" {
  ami           = "ami-0dcc0ebde7b2e00db" 
  instance_type = "t2.nano"
  key_name = aws_key_pair.test.key_name
  associate_public_ip_address = "true"
  vpc_security_group_ids = [aws_security_group.test.id]
  subnet_id   = aws_subnet.test.id
  private_ip = "10.0.0.5"
  count = var.enable_standalone_ec2 ? 1 : 0

#   network_interface {
#     network_interface_id = aws_network_interface.test.id
#     device_index         = 0
#   }

  tags = var.tags
}

resource "aws_internet_gateway" "test" {
  vpc_id = aws_vpc.test.id
  tags = var.tags
}

resource "aws_route_table" "test" {
  vpc_id = aws_vpc.test.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test.id
  }

  tags = var.tags
}

resource "aws_route_table_association" "test" {
  subnet_id      = aws_subnet.test.id
  route_table_id = aws_route_table.test.id
}

resource "aws_lb" "test" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.test.id]
  subnets            = [aws_subnet.test.id,aws_subnet.test2.id,]
 
  # subnet_mapping {
  #   subnet_id     = aws_subnet.test.id
  # }

  tags = var.tags
}

resource "aws_lb_target_group" "test" {
  name     = "test-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.test.id
}

resource "aws_lb_listener" "test" {
  load_balancer_arn = aws_lb.test.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.test.arn
  }
}

# resource "aws_lb_target_group_attachment" "test" {
#   target_group_arn = aws_lb_target_group.test.arn
#   target_id        = "i-008e53d542ac6fe81"
#   port             = 80
# }

# resource "aws_eip" "lb" {
#   instance = aws_lb.test.id
# }

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.test.zone_id
  name    = "service"
  type    = "CNAME"
  ttl     = "300"
  records = ["test-lb-tf-64514078.eu-central-1.elb.amazonaws.com"]
}

resource "aws_launch_configuration" "as_conf" {
  name_prefix   = "ASG"
  image_id      = "ami-0dcc0ebde7b2e00db" 
  instance_type = "t2.nano"
  key_name = aws_key_pair.test.key_name
  associate_public_ip_address = "true"
  security_groups = [aws_security_group.test.id]
  user_data = <<EOF
  #!/bin/bash
  sudo amazon-linux-extras install docker
  sudo service docker start
  docker pull ${var.docker_image}
  docker run -d -p 80:3000 ${var.docker_image}
  EOF
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "test" {
  name                 = "terraform-asg-example"
  launch_configuration = aws_launch_configuration.as_conf.name
  min_size             = 0
  max_size             = 5
  health_check_grace_period = 300
  health_check_type    = "ELB"
  desired_capacity     = var.number_ec2
  force_delete         = true
  target_group_arns = [aws_lb_target_group.test.arn]
  vpc_zone_identifier  = [aws_subnet.test.id]
  
    tags = concat(
    [
      {
        "key"                 = "Name"
        "value"               = "spbdki-19"
        "propagate_at_launch" = true
      },
      {
        "key"                 = "Owner"
        "value"               = "alakimov"
        "propagate_at_launch" = true
      },
      {
        "key"                 = "Project"
        "value"               = "internship"
        "propagate_at_launch" = true
      }
    ])

  lifecycle {
    create_before_destroy = true
  }
}