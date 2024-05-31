resource "aws_vpc" "my_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "dev"
  }
}

# Create two availability zones
variable "availability_zones" {
  default = ["eu-central-1a", "eu-central-1b"]
}

# Create public and private subnets in each AZ
resource "aws_subnet" "public_subnet" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "public-subnet-${count.index}"
  }
}

resource "aws_subnet" "private_subnet" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.${count.index + 10}.0/24" # Assuming private subnets start from 10.0.10.0/24
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "private-subnet-${count.index}"
  }
}

# Add private subnets for RDS
resource "aws_subnet" "private_rds1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.15.0/24"
  availability_zone = "eu-central-1a"

  tags = {
    Name = "my-private-rds-1"
  }
}

# Elastic IP
resource "aws_eip" "eip" {
  domain = "vpc"
}

# NAT gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public_subnet[0].id

  tags = {
    Name = "my-nat"
  }
}

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "dev-igw"
  }
}

resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "dev-rt"
  }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.my_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.my_igw.id
}

# Associate Route Table with Subnets
resource "aws_route_table_association" "public_subnet_association" {
  for_each       = { for idx, subnet in aws_subnet.public_subnet : idx => subnet.id }
  subnet_id      = each.value
  route_table_id = aws_route_table.my_route_table.id
}

# Add route table association for RDS subnet
resource "aws_route_table_association" "private_rds" {
  subnet_id      = aws_subnet.private_rds1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_security_group" "my_sg" {
  name        = "dev_sg"
  description = "allow SSH, HTTP, HTTPS, MySQL traffic"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3306 #MySQL port
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_instance" "dev_wp" {
  instance_type = "t3.micro"
  ami           = data.aws_ami.server_ami.id
  //key_name                    = aws_key_pair.my_auth.id
  key_name                    = "Capwpkey3"
  vpc_security_group_ids      = [aws_security_group.my_sg.id]
  subnet_id                   = aws_subnet.public_subnet[0].id
  associate_public_ip_address = true
  user_data                   = file("userdata.tpl")

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "dev-wp"
  }

  provisioner "local-exec" {
    command = "echo Instance Type = ${self.instance_type}, Instance ID = ${self.id}, Public IP = ${self.public_ip}, AMI ID = ${self.ami} >> metadata"
  }
}


# Security Group for the Bastion Host
resource "aws_security_group" "bastion_sg" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["YOUR PERSONAL IP/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-sg"
  }
}

# Launch the Bastion Host
resource "aws_instance" "bastion" {
  ami                         = "ami-08188d*"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet[0].id
  security_groups             = [aws_security_group.bastion_sg.id]
  key_name                    = "Capwpkey3-bh" # Replace with your key pair name
  associate_public_ip_address = true

  tags = {
    Name = "bastion-host"
  }
}

# Modify existing security group to allow SSH from Bastion Host
resource "aws_security_group_rule" "allow_ssh_from_bastion" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.my_sg.id
  source_security_group_id = aws_security_group.bastion_sg.id
}

# Associate Route Table with Private Subnets
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "private-rt"
  }
}

resource "aws_route_table_association" "private_subnet_association" {
  for_each       = { for idx, subnet in aws_subnet.private_subnet : idx => subnet.id }
  subnet_id      = each.value
  route_table_id = aws_route_table.private_route_table.id
}

# Additional configuration to route traffic from private subnets through NAT gateway
resource "aws_route" "nat_gateway_route" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

# Configure your private RDS subnet route table association if needed
resource "aws_route_table_association" "private_rds_route_association" {
  subnet_id      = aws_subnet.private_rds1.id
  route_table_id = aws_route_table.private_route_table.id
}

# Private Security Group for WordPress Servers
resource "aws_security_group" "private_wp_sg" {
  name        = "private_wp_sg"
  description = "Allow HTTP, HTTPS, and MySQL traffic from ALB and Bastion"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port         = 3306
    to_port           = 3306
    protocol          = "tcp"
    security_groups   = [aws_security_group.bastion_sg.id]
    description       = "Allow MySQL access from Bastion Host"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private_wp_sg"
  }
}

# WordPress EC2 Launch Template
resource "aws_launch_template" "wp" {
  name_prefix          = "wp-"
  image_id             = "ami-08188*"
  instance_type        = "t3.micro"
  key_name             = "Capwpkey3"
  vpc_security_group_ids = [aws_security_group.private_wp_sg.id]
  user_data            = base64encode(file("userdata.tpl"))

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 10
    }
  }

  tags = {
    Name = "wp-instance"
  }
}

# Auto Scaling Group for WordPress
resource "aws_autoscaling_group" "wp_asg" {
  desired_capacity     = 2
  max_size             = 3
  min_size             = 1
  vpc_zone_identifier  = [aws_subnet.private_subnet[0].id, aws_subnet.private_subnet[1].id]
  launch_template {
    id      = aws_launch_template.wp.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.wp_tg.arn]

  tag {
    key                 = "Name"
    value               = "wp-asg-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Application Load Balancer
resource "aws_lb" "alb" {
  name               = "wp-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.my_sg.id]
  subnets            = [aws_subnet.public_subnet[0].id, aws_subnet.public_subnet[1].id]

  enable_deletion_protection = false

  tags = {
    Name = "wp-alb"
  }
}

# Target Group for ALB
resource "aws_lb_target_group" "wp_tg" {
  name        = "wp-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.my_vpc.id
  target_type = "instance"
  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "wp-tg"
  }
}

# ALB Listener
resource "aws_lb_listener" "wp_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wp_tg.arn
  }

  tags = {
    Name = "wp-listener"
  }
}
