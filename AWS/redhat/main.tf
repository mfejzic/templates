

# Creates virtual private cloud
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    "Name" = "vpc${var.environment}"
  }
}

#----------------------------------- all subnets ------------------------------------#

# All available zones in current region
data "aws_availability_zones" "available" {
  state    = "available"
}

# Create public/private subnets

///public subents
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_subnet2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_cidr2
  map_public_ip_on_launch = true
}

// private subnets
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnet_cidr
  map_public_ip_on_launch = false
}

resource "aws_subnet" "private_subnet2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnet_cidr2
  map_public_ip_on_launch = false
}


#----------------------------------- nat & internet gateway ------------------------------------#

# creates internet gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id
}

resource "aws_eip" "nat_eip2" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gateway2" {
  allocation_id = aws_eip.nat_eip2.id
  subnet_id     = aws_subnet.public_subnet2.id
}

#----------------------------------- route tables ------------------------------------#

# public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = var.allow_all_cidr
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
}
# this blocks associates public subnet to route table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public.id
}

// public
resource "aws_route_table" "public2" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = var.allow_all_cidr
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
}
# this blocks associates public subnet to route table
resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public_subnet2.id
  route_table_id = aws_route_table.public2.id
}

# private route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = var.allow_all_cidr
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table" "private2" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = var.allow_all_cidr
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
}

resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.private_subnet2.id
  route_table_id = aws_route_table.private2.id
}

#----------------------------------- security groups ------------------------------------#

# Security group for bastion host (public subnet)
resource "aws_security_group" "bastion_sg" {
  vpc_id      = aws_vpc.vpc.id
  name        = "bastion-sg"
  description = "Allow inbound SSH to bastion"
  ingress {
    description = "SSH from public"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allow_all_cidr]
  }
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.allow_all_cidr]
  }
}

# Security group for ec2 (private subnet)
resource "aws_security_group" "ec2_sg" {
  vpc_id      = aws_vpc.vpc.id
  name        = "ec2-sg"
  description = "Allow HTTP from ALB and SSH from bastion"
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.allow_all_cidr]
  }
}

# Security group for load balancer
resource "aws_security_group" "alb_sg" {
  vpc_id      = aws_vpc.vpc.id
  name        = "alb-sg"
  description = "Allow inbound HTTP/HTTPS to ALB"
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allow_all_cidr]
  }
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.allow_all_cidr]
  }
#   egress {
#     description     = "Outbound to EC2 targets"
#     from_port       = 80  
#     to_port         = 80
#     protocol        = "tcp"
#     security_groups = [aws_security_group.ec2_sg.id] 
#   }
}

# Security group for PostgreSQL
resource "aws_security_group" "sql_sg" {
  vpc_id      = aws_vpc.vpc.id
  name        = "sql-sg"
  description = "Allow PostgreSQL from EC2"
  ingress {
    description     = "PostgreSQL from EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
    
  }
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.allow_all_cidr]
  }
}

# Security group for Redis
resource "aws_security_group" "redis_sg" {
  vpc_id      = aws_vpc.vpc.id
  name        = "redis-sg"
  description = "Allow Redis from EC2"
  ingress {
    description     = "Redis from EC2"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id] 
  }
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.allow_all_cidr]
  }
}

#----------------------------------- load balancer & ssl------------------------------------#

resource "aws_lb" "test" {
  name               = "primary-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet.id, aws_subnet.public_subnet2.id]

  enable_deletion_protection = false
}

// these two blocks create target groups for https and http

resource "aws_lb_target_group" "https" {                                         // attached inside the asg block
  name        = "ip-target-group-https"
  port        = 443
  protocol    = "HTTPS"
  target_type = "instance"
  vpc_id      = aws_vpc.vpc.id

  health_check {
    path                = "/health"
    port                = 443
    protocol            = "HTTPS"
    matcher             = "200"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "http" {
  name        = "ip-target-group-http"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.vpc.id

  health_check {
    path                = "/health"
    port                = 80
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

/// throw ssl content under here

#----------------------------------- key pairs ------------------------------------#

resource "tls_private_key" "generated" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}
resource "local_file" "generated" {
  content  = tls_private_key.generated.private_key_pem
  filename = var.aws_privatekey_file_name_localmachine
}
resource "aws_key_pair" "keypair" {
  key_name   = var.aws_keypair_name
  public_key = tls_private_key.generated.public_key_openssh
}

#----------------------------------- bastion host ------------------------------------#

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  key_name      = aws_key_pair.keypair.key_name
  security_groups = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true
}

#----------------------------------- ec2 & auto scaling------------------------------------#

data "aws_ami" "redhat" {
  most_recent = true
  owners      = ["309956199498"]  # Red Hat owner ID
  filter {
    name   = "name"
    values = ["RHEL-8.*_HVM-*-x86_64-*"]
  }
}

resource "aws_launch_template" "ec2_template" {
  name_prefix   = "ec2-template"
  image_id      = data.aws_ami.redhat.id
  //name = "redhat" add quantifier
  instance_type = "t2.micro"
  key_name      = aws_key_pair.keypair.key_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  user_data     = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    EOF
  )
}

resource "aws_autoscaling_group" "ec2_asg" {
  vpc_zone_identifier = [aws_subnet.private_subnet.id]
  min_size = 1
  max_size = 3

  launch_template {
    id      = aws_launch_template.ec2_template.id
    version = "$Latest"
  }

  target_group_arns = [
    aws_lb_target_group.http.arn, 
    aws_lb_target_group.https.arn
  ]
}

#----------------------------------- postgre sql ------------------------------------#
// best for write heavy workloads

// PostgreSQL RDS instance
resource "aws_db_instance" "postgres_db" {
  identifier            = "my-postgres-db"
  engine                = "postgres"
  engine_version        = "16.3"                                                            // latest stable version as of today
  instance_class        = "db.t3.micro"                                                     // use this tiny engine for testing; scale up for prod
  allocated_storage     = 20                                                                // gigabytes
  storage_type          = "gp2"
  username              = "adminuser"                              
  password              = "password1"  
  db_name               = "main"  
  
  publicly_accessible   = false                                                             // Keep private
  multi_az              = false                                                              // Single AZ for testing; enable for HA
  skip_final_snapshot   = true                                                              // Skip snapshot on delete for testing

  db_subnet_group_name  = aws_db_subnet_group.group.name  

  vpc_security_group_ids = [
    aws_security_group.sql_sg.id
  ]                                   // must allow entry from redhat instance
}

# DB Subnet Group for Private Subnets
resource "aws_db_subnet_group" "group" {
  name       = "private-db-subnet-group"
  subnet_ids = [
    aws_subnet.private_subnet2.id, aws_subnet.private_subnet.id
  ]                                         // Use your private subnet(s); if multiple, use [aws_subnet.private1.id, aws_subnet.private2.id]

  tags = {
    Name = "private-db-subnet-group-${var.environment}"
  }
}

#----------------------------------- elasticache redis ------------------------------------#


#----------------------------------- monitoring ------------------------------------#


#----------------------------------- route 53 ------------------------------------#


