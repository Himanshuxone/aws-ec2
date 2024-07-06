terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

### configure the aws provider
provider "aws" {
  region = "ap-south-1"
}


### create vm instance with ami
resource "aws_instance" "instance_1" {
  ami             = var.ami_id ## Ubuntu 20.04 LTS
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.instances.name]
  user_data       = <<-EOF
        #!/bin/bash
        echo "Hello World 1" > index.html
        python3 -m http.server 9090 &
        EOF
}

### create vm instance with ami
resource "aws_instance" "instance_2" {
  ami             = var.ami_id ## Ubuntu 20.04 LTS
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.instances.name]
  user_data       = <<-EOF
        #!/bin/bash
        echo "Hello World 2" > index.html
        python3 -m http.server 9090 &
        EOF
}

### Use default vpc
data "aws_vpc" "default_vpc" {
  default = true
}

data "aws_subnets" "default_subnet" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_vpc.id]
  }
}

data "aws_subnet" "default_subnet" {
  for_each = toset(data.aws_subnets.default_subnet.ids)
  id       = each.value
}

// add a security group for inbound access to the ec2 from outside
resource "aws_security_group" "instances" {
  name = "instance-security-group"
}

resource "aws_security_group_rule" "allow_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.instances.id

  from_port   = 9090
  to_port     = 9090
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

output "subnet_list" {
  value = aws_lb.load_balancer.arn
}

### to have inbound traffic from outside
resource "aws_lb_listener" "http" {
  for_each = aws_lb.load_balancer.arn
  load_balancer_arn = each.key

  port = 9090

  protocol = "HTTP"

  # By default, return a simple 404 page
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

resource "aws_lb_target_group" "instances" {
  name     = "example-target-group"
  port     = 9090
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default_vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

## attach load balanacer to the instance once it is running to tell it to send the traffic to the instance
resource "aws_lb_target_group_attachment" "instance_1" {
  target_group_arn = aws_lb_target_group.instances.arn
  target_id        = aws_instance.instance_1.id
  port             = 9090
}

resource "aws_lb_target_group_attachment" "instance_2" {
  target_group_arn = aws_lb_target_group.instances.arn
  target_id        = aws_instance.instance_2.id
  port             = 9090
}

resource "aws_lb_listener_rule" "instances" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.instances.arn
  }
}

### create security group for the load balancer
resource "aws_security_group" "alb" {
  name = "alb-security-group"
}

resource "aws_security_group_rule" "allow_alb_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.alb.id

  from_port   = 9090
  to_port     = 9090
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_alb_http_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.alb.id

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}

### finally create a load balancer for a subnet
resource "aws_lb" "load_balancer" {
    name               = "web-app-lb"
    load_balancer_type = "application"
    subnets            = data.aws_subnets.default_subnet.ids
    security_groups    = [aws_security_group.alb.id]
}

resource "aws_route53_zone" "primary" {
  name = "finte.in"
}

resource "aws_route53_record" "root" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "finte.in"
  type    = "A"

  alias {
    name                   = aws_lb.load_balancer.dns_name
    zone_id                = aws_lb.load_balancer.zone_id
    evaluate_target_health = true
  }
}

resource "aws_db_instance" "db_instance" {
  allocated_storage   = 20
  storage_type        = "standard"
  engine              = "postgress"
  engine_version      = "12.5"
  instance_class      = "db.t2.micro"
  username            = "mydb"
  password            = "foobarbaz"
  skip_final_snapshot = true
}

