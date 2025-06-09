##############################################################################################################################
#                                                           US-EAST-1                                                        #
##############################################################################################################################
##############################################################################################################################
#                                      VIRTUAL PRIVATE CLOUD + NETWORK ACCESS CONTROL LIST                                   #
##############################################################################################################################

# Create virtual private cloud
resource "aws_vpc" "vpc" {
  provider   = aws.primary
  cidr_block = var.vpc_cidr
  tags = {
    "Name" = "vpc${var.environment}"
  }
}

# Create network access control list
resource "aws_network_acl" "nacl" {
  provider = aws.primary
  vpc_id   = aws_vpc.vpc.id
}

# Define inbound and outbound rules to allow all traffic
resource "aws_network_acl_rule" "allow_all_inbound" {
  provider       = aws.primary
  rule_number    = 100
  network_acl_id = aws_network_acl.nacl.id
  rule_action    = var.rule_action_allow
  protocol       = "-1"               
  cidr_block     = var.allow_all_cidr #
  from_port      = 0                  
  to_port        = 65535              
  egress         = false              
}
resource "aws_network_acl_rule" "allow_all_outbound" {
  provider       = aws.primary
  rule_number    = 100
  network_acl_id = aws_network_acl.nacl.id
  rule_action    = var.rule_action_allow
  protocol       = "-1"               
  cidr_block     = var.allow_all_cidr 
  from_port      = 0                  
  to_port        = 65535              
  egress         = true               
}

# Associate nacl with subnets
resource "aws_network_acl_association" "nacl_public_association" {
  provider       = aws.primary
  for_each       = aws_subnet.public_subnets
  network_acl_id = aws_network_acl.nacl.id
  subnet_id      = aws_subnet.public_subnets[each.key].id
}
resource "aws_network_acl_association" "nacl_private_association" {
  provider       = aws.primary
  for_each       = aws_subnet.private_subnets
  network_acl_id = aws_network_acl.nacl.id
  subnet_id      = aws_subnet.private_subnets[each.key].id
}


##############################################################################################################################
#                                             SUBNETS + GATEWAYS + ROUTE TABLES                                              #
##############################################################################################################################


#All available zones in current region
data "aws_availability_zones" "available" {
  provider = aws.primary
  state    = "available"
}

# Create public/private subnets
resource "aws_subnet" "public_subnets" {
  provider                = aws.primary
  for_each                = var.public_subnets
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value + 100)
  availability_zone       = tolist(data.aws_availability_zones.available.names)[each.value]
  map_public_ip_on_launch = true
  tags = {
    Name = "${each.key}"
  }
}
resource "aws_subnet" "private_subnets" {
  provider          = aws.primary
  for_each          = var.private_subnets
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value)
  map_public_ip_on_launch = false
  availability_zone = tolist(data.aws_availability_zones.available.names)[each.value]
  tags = {
    Name = "${each.key}"
  }
}

# Create internet gateway
resource "aws_internet_gateway" "igw" {
  provider = aws.primary
  vpc_id   = aws_vpc.vpc.id

  tags = {
    Name = "igw${var.environment}"
  }
}

#Create elastic IP for NAT Gateway/nat gateway needs eip
resource "aws_eip" "eip_1" {
  provider   = aws.primary
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
  tags = {
    Name = "eip${var.environment}"
  }
}
resource "aws_eip" "eip_2" {
  provider   = aws.primary
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
  tags = {
    Name = "eip${var.environment}"
  }
}

# Create NAT Gateway for each public subnet
resource "aws_nat_gateway" "ngw_public_subnet_1" {
  provider      = aws.primary
  depends_on    = [aws_subnet.public_subnets]
  allocation_id = aws_eip.eip_1.id
  subnet_id     = aws_subnet.public_subnets["public_subnet_1"].id
  tags = {
    Name = "ngw_public_subnet_1${var.environment}"
  }
}
resource "aws_nat_gateway" "ngw_public_subnet_2" {
  provider      = aws.primary
  depends_on    = [aws_subnet.public_subnets]
  allocation_id = aws_eip.eip_2.id
  subnet_id     = aws_subnet.public_subnets["public_subnet_2"].id
  tags = {
    Name = "ngw_public_subnet_2${var.environment}"
  }
}

# Create public/private route tables
resource "aws_route_table" "public_rtb" {
  provider = aws.primary
  vpc_id   = aws_vpc.vpc.id

  route {
    cidr_block = var.allow_all_cidr
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public_rtb${var.environment}"
  }
}
resource "aws_route_table" "private_rtb_1" {
  vpc_id   = aws_vpc.vpc.id
  provider = aws.primary

  route {
    cidr_block     = var.allow_all_cidr
    nat_gateway_id = aws_nat_gateway.ngw_public_subnet_1.id
  }

  tags = {
    Name = "private_rtb_1${var.environment}"
  }
}
resource "aws_route_table" "private_rtb_2" {
  provider = aws.primary
  vpc_id   = aws_vpc.vpc.id

  route {
    cidr_block     = var.allow_all_cidr
    nat_gateway_id = aws_nat_gateway.ngw_public_subnet_2.id
  }

  tags = {
    Name = "private_rtb_2${var.environment}"
  }
}

# Associate route tables with subnets
resource "aws_route_table_association" "public_rta" {
  provider       = aws.primary
  depends_on     = [aws_subnet.public_subnets]
  for_each       = aws_subnet.public_subnets
  subnet_id      = aws_subnet.public_subnets[each.key].id
  route_table_id = aws_route_table.public_rtb.id
}
resource "aws_route_table_association" "private_rta_1" {
  provider       = aws.primary
  depends_on     = [aws_subnet.private_subnets]
  subnet_id      = aws_subnet.private_subnets["private_subnet_1"].id
  route_table_id = aws_route_table.private_rtb_1.id
}
resource "aws_route_table_association" "private_rta_2" {
  provider       = aws.primary
  depends_on     = [aws_subnet.private_subnets]
  subnet_id      = aws_subnet.private_subnets["private_subnet_2"].id
  route_table_id = aws_route_table.private_rtb_2.id
}


##############################################################################################################################
#                                                     SECURITY GROUPS                                                        #
##############################################################################################################################


# Create security group for bastion host
resource "aws_security_group" "bastion_sg" {
  provider    = aws.primary
  name        = "bastion_sg"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress = [{
    cidr_blocks      = [var.allow_all_cidr]
    description      = "allow ssh in"
    from_port        = 22
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = []
    self             = true
    to_port          = 22
  }]
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    cidr_blocks = [var.allow_all_cidr]
  }

  tags = {
    Name = "bastion_sg${var.environment}"
  }
}

# Create security group for load balancer
resource "aws_security_group" "alb_sg" {
  provider    = aws.primary
  name        = "alb_sg"
  description = "Allow http/https inbound/outbound traffic for alb"
  vpc_id      = aws_vpc.vpc.id

  ingress = [{
    cidr_blocks      = [var.allow_all_cidr]
    description      = "allow https in"
    from_port        = 443
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = []
    self             = true
    to_port          = 443
    }, {
    cidr_blocks      = [var.allow_all_cidr]
    description      = "allow http in"
    from_port        = 80
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = []
    self             = true
    to_port          = 80
    }, {
    cidr_blocks      = [var.allow_all_cidr]
    description      = "allow http in"
    from_port        = -1
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "icmp"
    security_groups  = []
    self             = true
    to_port          = -1
  }]

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.allow_all_cidr]
  }

  tags = {
    "Name" = "alb_sg${var.environment}"
  }
}

# Create security group for private instances
resource "aws_security_group" "private_ec2_web_sg" {
  provider    = aws.primary
  name        = "private_ec2_web_sg"
  description = "https/https out // alb_sg/bastion_sg in"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    self            = true
    cidr_blocks     = [var.allow_all_cidr]
    security_groups = [aws_security_group.bastion_sg.id, aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    cidr_blocks = [var.allow_all_cidr]
  }

  tags = {
    "Name" = "private_ec2_web_sg${var.environment}"
  }
}


##############################################################################################################################
#                                                    KEY PAIRS + INSTANCES                                                   #
##############################################################################################################################


# Create key pair / Store private key on local machine
resource "tls_private_key" "generated" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}
resource "local_file" "generated" {
  content  = tls_private_key.generated.private_key_pem
  filename = var.aws_privatekey_file_name_localmachine
}
resource "aws_key_pair" "keypair" {
  provider   = aws.primary
  key_name   = var.aws_keypair_name
  public_key = tls_private_key.generated.public_key_openssh
}

# Use latest ubuntu AMI
data "aws_ami" "ubuntu" {
  provider    = aws.primary
  most_recent = true

  filter {
    name   = "name"
    values = ["zx_ubuntu22"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["334577349345"]
}

# Use cloud-config for user data 
data "template_file" "user_data" {
  template = file("userdata.yaml")
}

# Create instances
resource "aws_instance" "bastion_instance" {
  provider                    = aws.primary
  for_each                    = aws_subnet.public_subnets
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  subnet_id                   = aws_subnet.public_subnets[each.key].id
  key_name                    = aws_key_pair.keypair.key_name
  associate_public_ip_address = true

  tags = {
    Name = "bastion_${each.key}${var.environment}"
  }

  # Display private/public IP's in text file
  provisioner "local-exec" {
    command = <<-EOT
      echo "${self.private_ip} >> private_ips_bastion.txt"
      echo "${self.public_ip} >> public_ips_bastion.txt"
    EOT
  }
}
resource "aws_instance" "private_ec2" {
  provider                    = aws.primary
  for_each                    = aws_subnet.private_subnets
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id, aws_security_group.private_ec2_web_sg.id]
  subnet_id                   = aws_subnet.private_subnets[each.key].id
  key_name                    = aws_key_pair.keypair.key_name
  user_data                   = data.template_file.user_data.rendered
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name

  # Display private IP's in text file
  provisioner "local-exec" {
    command = <<-EOT
      echo "${self.private_ip} >> private_ips_ec2.txt"
    EOT
  }

  tags = {
    Name = "ec2_${each.key}${var.environment}"
  }
}


##############################################################################################################################
#                             APPLICATION LOAD BALANCER + AUTO SCALING GROUP + CERTIFICATE MANAGER                           #
##############################################################################################################################


# Create application load balancer
resource "aws_lb" "alb" {
  provider                   = aws.primary
  name                       = "alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb_sg.id]
  enable_deletion_protection = false
  ip_address_type            = "ipv4"
  enable_http2               = true
  subnets = [aws_subnet.public_subnets["public_subnet_1"].id,
  aws_subnet.public_subnets["public_subnet_2"].id]

  tags = {
    Name = "alb${var.environment}"
  }
}

# Create target groups for http/https
resource "aws_lb_target_group" "ip_target_group_https" {
  provider    = aws.primary
  name        = "ip-target-group-https"
  port        = 443
  protocol    = "HTTPS"
  target_type = "ip"
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
resource "aws_lb_target_group" "ip_target_group_http" {
  provider    = aws.primary
  name        = "ip-target-group-http"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
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

# Attach target groups to load balancer
resource "aws_lb_target_group_attachment" "tg_attachment_https" {
  provider         = aws.primary
  for_each         = aws_instance.private_ec2
  target_group_arn = aws_lb_target_group.ip_target_group_https.arn
  target_id        = aws_instance.private_ec2[each.key].private_ip
  port             = 443
}
resource "aws_lb_target_group_attachment" "tg_attachment_http" {
  provider         = aws.primary
  for_each         = aws_instance.private_ec2
  target_group_arn = aws_lb_target_group.ip_target_group_http.arn
  target_id        = aws_instance.private_ec2[each.key].private_ip
  port             = 80
}

# Add listeners for port 80/443
resource "aws_lb_listener" "http_listener" {
  provider          = aws.primary
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "redirect"
    target_group_arn = aws_lb_target_group.ip_target_group_http.arn

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
resource "aws_lb_listener" "https_listener" {
  provider          = aws.primary
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = data.aws_acm_certificate.amazon_issued.arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ip_target_group_https.arn
  }
}

# Create listener rules to forward traffic to dedicated target group
resource "aws_lb_listener_rule" "https_rule" {
  provider     = aws.primary
  listener_arn = aws_lb_listener.https_listener.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ip_target_group_https.arn
  }

  condition {
    host_header {
      values = ["www.fejzic37.com"]
    }
  }
}
resource "aws_lb_listener_rule" "http_rule" {
  provider     = aws.primary
  listener_arn = aws_lb_listener.http_listener.arn
  priority     = 2

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ip_target_group_http.arn
  }

  condition {
    host_header {
      values = ["www.fejzic37.com"]
    }
  }
}

# Use exisitng certificate in acm console
data "aws_acm_certificate" "amazon_issued" {
  provider    = aws.primary
  domain      = var.subdomain_name
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

# Apply certificate to https listener 
resource "aws_lb_listener_certificate" "alb_listener_certificate" {
  provider        = aws.primary
  listener_arn    = aws_lb_listener.https_listener.arn
  certificate_arn = data.aws_acm_certificate.amazon_issued.arn
}

# Create launch template for auto scaling
resource "aws_launch_template" "launch_template" {
  provider      = aws.primary
  name          = "launch_template"
  instance_type = var.instance_type
  key_name      = var.aws_keypair_name
  image_id      = data.aws_ami.ubuntu.id

  placement {
    availability_zone = data.aws_availability_zones.available.id
  }

  vpc_security_group_ids = [aws_security_group.private_ec2_web_sg.id]
  tags = {
    "Name" = "launch_template${var.environment}"
  }

  user_data = filebase64("userdata.yaml")
}

# Create auto scaling group/ attach launch template
resource "aws_autoscaling_group" "asg" {
  provider                  = aws.primary
  name                      = "asg${var.environment}"
  max_size                  = 1
  min_size                  = 0
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 0
  force_delete              = true
  vpc_zone_identifier = [aws_subnet.private_subnets["private_subnet_1"].id,
  aws_subnet.private_subnets["private_subnet_2"].id]

  launch_template {
    id      = aws_launch_template.launch_template.id
    version = "$Latest"
  }
}


##############################################################################################################################
#                                               S3 + IDENTITY AND ACCESS MANAGEMENT                                          #
##############################################################################################################################


# Create an S3 bucket
resource "aws_s3_bucket" "ec2_bucket" {
  provider = aws.primary
  bucket   = "mfejzic37"
}

# Enable public access to bucket objects
resource "aws_s3_bucket_public_access_block" "ec2_bucket" {
  provider                = aws.primary
  bucket                  = aws_s3_bucket.ec2_bucket.bucket
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Upload index.html to bucket
resource "aws_s3_object" "ec2_bucket" {
  provider = aws.primary
  depends_on = [
    aws_s3_bucket.ec2_bucket
  ]
  bucket                 = aws_s3_bucket.ec2_bucket.bucket
  key                    = "host/index.html"
  source                 = "./index.html"
  server_side_encryption = "AES256"
  content_type           = "text/html"
}

# Encrypt bucket objects 
resource "aws_s3_bucket_server_side_encryption_configuration" "ec2_bucket" {
  provider = aws.primary
  bucket   = aws_s3_bucket.ec2_bucket.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Enable versioning for accidental deletion
resource "aws_s3_bucket_versioning" "ec2_bucket" {
  provider = aws.primary
  bucket   = aws_s3_bucket.ec2_bucket.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

# Create IAM role/policy for ec2 to access s3/ ec2 will fetch index.html 
resource "aws_iam_role" "ec2_role" {
  provider = aws.primary
  name     = "web_server_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}
resource "aws_iam_policy" "s3_access_policy" {
  provider    = aws.primary
  name        = "s3_access_policy"
  description = "IAM policy for EC2 to access S3"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ],
        Effect = "Allow",
        Resource = [
          "arn:aws:s3:::${var.bucket_name}",
          "arn:aws:s3:::${var.bucket_name}/index.html",
        ],
      },
    ],
  })
}

# Attach policy to appropriate role
resource "aws_iam_policy_attachment" "access_to_s3_attachment" {
  provider   = aws.primary
  name       = "attachment"
  policy_arn = aws_iam_policy.s3_access_policy.arn
  roles      = [aws_iam_role.ec2_role.name]
}
resource "aws_iam_policy_attachment" "ec2_fetch_attachment" {
  provider   = aws.primary
  name       = "ec2 fetch"
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  roles      = [aws_iam_role.ec2_role.name]
}

# Create instance profile and attach to private instance block
resource "aws_iam_instance_profile" "ec2_profile" {
  provider = aws.primary
  name     = "ec2_profile"
  role     = aws_iam_role.ec2_role.name
}


##############################################################################################################################
#                                           CLOUDWATCH + SIMPLE NOTIFICATION SERVICE                                        #
##############################################################################################################################


# Create a CloudWatch metric alarm for GET request metrics
resource "aws_cloudwatch_metric_alarm" "get_requests_S3_alarm" {
  provider            = aws.primary
  alarm_name          = "GetRequests"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "GetRequests"
  namespace           = "AWS/S3"
  period              = 60
  statistic           = "Sum"
  unit                = "Count"
  threshold           = 3
  alarm_description   = "Alarm for S3 number of GetRequests exceeding threshold"
  alarm_actions       = [aws_sns_topic.sns.arn]
  dimensions = {
    BucketName = aws_s3_bucket.ec2_bucket.bucket
  }

  tags = {
    "Name" = "cloudwatch_fetchS3${var.environment}"
  }
}

# Define an SNS topic for alarm notifications
resource "aws_sns_topic" "sns" {
  provider = aws.primary
  name     = "s3_request_sns"

  tags = {
    "Name" = "sns${var.environment}"
  }
}
# Subscribe to the SNS topic 
resource "aws_sns_topic_subscription" "sns" {
  provider  = aws.primary
  topic_arn = aws_sns_topic.sns.arn
  protocol  = "email"
  endpoint  = "muhazic3@gmail.com"
}


# ##############################################################################################################################
#                                                           Route 53                                                           #
# ##############################################################################################################################


# Create primary and secondary alias with failover policy / secondary points to us-west-2 load balancer
resource "aws_route53_record" "primary_alias" {
  provider = aws.primary
  zone_id  = var.subdomain_name
  name     = var.subdomain_name
  type     = "A"

  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
  failover_routing_policy {
    type = "PRIMARY"
  }
  set_identifier  = "primary"
  health_check_id = aws_route53_health_check.primary.id
}
resource "aws_route53_record" "secondary_alias" {
  provider = aws.secondary
  zone_id  = var.subdomain_name
  name     = var.subdomain_name
  type     = "A"

  alias {
    name                   = aws_lb.alb_sec.dns_name
    zone_id                = aws_lb.alb_sec.zone_id
    evaluate_target_health = true
  }
  failover_routing_policy {
    type = "SECONDARY"
  }
  set_identifier  = "secondary"
  health_check_id = aws_route53_health_check.secondary.id
}

# Create health check for primary and secondary records
resource "aws_route53_health_check" "primary" {
  provider          = aws.primary
  fqdn              = var.subdomain_name
  port              = 443
  type              = "HTTPS"
  request_interval  = 30
  failure_threshold = 3
  tags = {
    Name = "primary_health_check"
  }
}
resource "aws_route53_health_check" "secondary" {
  provider          = aws.primary
  fqdn              = var.subdomain_name
  port              = 443
  type              = "HTTPS"
  request_interval  = 30
  failure_threshold = 3
  tags = {
    Name = "secondary_health_check"
  }
}


##############################################################################################################################
#                                                           US-WEST-2                                                        #
##############################################################################################################################
##############################################################################################################################
#                                      VIRTUAL PRIVATE CLOUD + NETWORK ACCESS CONTROL LIST                                   #
##############################################################################################################################


resource "aws_vpc" "vpc_sec" {
  provider   = aws.secondary
  cidr_block = var.vpc_cidr_sec
  tags = {
    "Name" = "vpc${var.environment_sec}"
  }
}

resource "aws_network_acl" "nacl_sec" {
  provider = aws.secondary
  vpc_id   = aws_vpc.vpc_sec.id
}

resource "aws_network_acl_rule" "allow_all_inbound_sec" {
  provider       = aws.secondary
  rule_number    = 100
  network_acl_id = aws_network_acl.nacl_sec.id
  rule_action    = var.rule_action_allow
  protocol       = "-1"
  cidr_block     = var.allow_all_cidr
  from_port      = 0
  to_port        = 65535
  egress         = false
}
resource "aws_network_acl_rule" "allow_all_outbound_sec" {
  provider       = aws.secondary
  rule_number    = 100
  network_acl_id = aws_network_acl.nacl_sec.id
  rule_action    = var.rule_action_allow
  protocol       = "-1"
  cidr_block     = var.allow_all_cidr
  from_port      = 0
  to_port        = 65535
  egress         = true
}

resource "aws_network_acl_association" "nacl_public_association_sec" {
  provider       = aws.secondary
  for_each       = aws_subnet.public_subnets_sec
  network_acl_id = aws_network_acl.nacl_sec.id
  subnet_id      = aws_subnet.public_subnets_sec[each.key].id
}
resource "aws_network_acl_association" "nacl_private_association_sec" {
  provider       = aws.secondary
  for_each       = aws_subnet.private_subnets_sec
  network_acl_id = aws_network_acl.nacl_sec.id
  subnet_id      = aws_subnet.private_subnets_sec[each.key].id
}


###############################################################################################################################
#                                              SUBNETS + GATEWAYS + ROUTE TABLES                                              #
###############################################################################################################################


data "aws_availability_zones" "available_sec" {
  provider = aws.secondary
  state    = "available"
}

resource "aws_subnet" "public_subnets_sec" {
  provider                = aws.secondary
  for_each                = var.public_subnets_sec
  vpc_id                  = aws_vpc.vpc_sec.id
  cidr_block              = cidrsubnet(var.vpc_cidr_sec, 8, each.value + 100)
  availability_zone       = tolist(data.aws_availability_zones.available_sec.names)[each.value]
  map_public_ip_on_launch = true
  tags = {
    Name = "${each.key}"
  }
}
resource "aws_subnet" "private_subnets_sec" {
  provider          = aws.secondary
  for_each          = var.private_subnets_sec
  vpc_id            = aws_vpc.vpc_sec.id
  cidr_block        = cidrsubnet(var.vpc_cidr_sec, 8, each.value)
  availability_zone = tolist(data.aws_availability_zones.available_sec.names)[each.value]
  tags = {
    Name = "${each.key}"
  }
}

resource "aws_internet_gateway" "igw_sec" {
  provider = aws.secondary
  vpc_id   = aws_vpc.vpc_sec.id

  tags = {
    Name = "igw${var.environment_sec}"
  }
}

resource "aws_eip" "eip_1_sec" {
  provider = aws.secondary
  domain   = "vpc"

  depends_on = [aws_internet_gateway.igw_sec]
  tags = {
    Name = "eip${var.environment_sec}"
  }
}
resource "aws_eip" "eip_2_sec" {

  provider = aws.secondary
  domain   = "vpc"

  depends_on = [aws_internet_gateway.igw_sec]
  tags = {
    Name = "eip${var.environment_sec}"
  }
}

resource "aws_nat_gateway" "ngw_public_subnet_1_sec" {
  provider      = aws.secondary
  depends_on    = [aws_subnet.public_subnets_sec]
  allocation_id = aws_eip.eip_1_sec.id
  subnet_id     = aws_subnet.public_subnets_sec["public_subnet_1"].id

  tags = {
    Name = "ngw_public_subnet_1${var.environment_sec}"
  }
}
resource "aws_nat_gateway" "ngw_public_subnet_2_sec" {
  provider      = aws.secondary
  depends_on    = [aws_subnet.public_subnets_sec]
  allocation_id = aws_eip.eip_2_sec.id
  subnet_id     = aws_subnet.public_subnets_sec["public_subnet_2"].id

  tags = {
    Name = "ngw_public_subnet_2${var.environment_sec}"
  }
}

resource "aws_route_table" "public_rtb_sec" {
  provider = aws.secondary
  vpc_id   = aws_vpc.vpc_sec.id

  route {
    cidr_block = var.allow_all_cidr
    gateway_id = aws_internet_gateway.igw_sec.id
  }

  tags = {
    Name = "public_rtb${var.environment_sec}"
  }
}
resource "aws_route_table" "private_rtb_1_sec" {
  provider = aws.secondary
  vpc_id   = aws_vpc.vpc_sec.id

  route {
    cidr_block     = var.allow_all_cidr
    nat_gateway_id = aws_nat_gateway.ngw_public_subnet_1_sec.id
  }

  tags = {
    Name = "private_rtb_1${var.environment_sec}"
  }
}
resource "aws_route_table" "private_rtb_2_sec" {
  provider = aws.secondary
  vpc_id   = aws_vpc.vpc_sec.id

  route {
    cidr_block     = var.allow_all_cidr
    nat_gateway_id = aws_nat_gateway.ngw_public_subnet_2_sec.id
  }

  tags = {
    Name = "private_rtb_2${var.environment_sec}"
  }
}

resource "aws_route_table_association" "public_rta_sec" {
  provider       = aws.secondary
  depends_on     = [aws_subnet.public_subnets_sec]
  for_each       = aws_subnet.public_subnets_sec
  subnet_id      = aws_subnet.public_subnets_sec[each.key].id
  route_table_id = aws_route_table.public_rtb_sec.id
}
resource "aws_route_table_association" "private_rta_1_sec" {
  provider       = aws.secondary
  depends_on     = [aws_subnet.private_subnets_sec]
  subnet_id      = aws_subnet.private_subnets_sec["private_subnet_1"].id
  route_table_id = aws_route_table.private_rtb_1_sec.id
}
resource "aws_route_table_association" "private_rta_2_sec" {
  provider       = aws.secondary
  depends_on     = [aws_subnet.private_subnets_sec]
  subnet_id      = aws_subnet.private_subnets_sec["private_subnet_2"].id
  route_table_id = aws_route_table.private_rtb_2_sec.id
}


# ##############################################################################################################################
# #                                                     SECURITY GROUPS                                                        #
# ##############################################################################################################################


resource "aws_security_group" "bastion_sg_sec" {
  provider    = aws.secondary
  name        = "bastion_sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.vpc_sec.id

  ingress = [{
    cidr_blocks      = [var.allow_all_cidr]
    description      = "allow ssh in"
    from_port        = 22
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = []
    self             = true
    to_port          = 22
  }]
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    cidr_blocks = [var.allow_all_cidr]
  }

  tags = {
    Name = "bastion_sg${var.environment_sec}"
  }
}

resource "aws_security_group" "alb_sg_sec" {
  provider    = aws.secondary
  name        = "alb_sg"
  description = "Allow http/https inbound/outbound traffic for alb"
  vpc_id      = aws_vpc.vpc_sec.id

  ingress = [{
    cidr_blocks      = [var.allow_all_cidr]
    description      = "allow https in"
    from_port        = 443
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = []
    self             = true
    to_port          = 443
    }, {
    cidr_blocks      = [var.allow_all_cidr]
    description      = "allow http in"
    from_port        = 80
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = []
    self             = true
    to_port          = 80
    }, {
    cidr_blocks      = [var.allow_all_cidr]
    description      = "allow http in"
    from_port        = -1
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "icmp"
    security_groups  = []
    self             = true
    to_port          = -1
  }]

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.allow_all_cidr]
  }

  tags = {
    "Name" = "alb_sg${var.environment_sec}"
  }
}
resource "aws_security_group" "private_ec2_web_sg_sec" {
  provider    = aws.secondary
  name        = "private_ec2_web_sg"
  description = "https/https out // alb/bastion in"
  vpc_id      = aws_vpc.vpc_sec.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    self        = true
    cidr_blocks = []

    security_groups = [aws_security_group.alb_sg_sec.id, aws_security_group.bastion_sg_sec.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    cidr_blocks = [var.allow_all_cidr]
  }

  tags = {
    "Name" = "private_ec2_web_sg${var.environment_sec}"
  }
}


# ##############################################################################################################################
# #                                                    KEY PAIRS + INSTANCES                                                   #
# ##############################################################################################################################


resource "tls_private_key" "generated_sec" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}
resource "local_file" "generated_sec" {
  content  = tls_private_key.generated_sec.private_key_pem
  filename = var.aws_privatekey_file_name_localmachine_sec
}
resource "aws_key_pair" "keypair_sec" {
  key_name   = var.aws_keypair_name_sec
  provider   = aws.secondary
  public_key = tls_private_key.generated_sec.public_key_openssh
}

data "aws_ami" "ubuntu_sec" {
  provider    = aws.secondary
  most_recent = true

  filter {
    name   = "name"
    values = ["ztna_ubuntu2004"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["704109570831"]
}

data "template_file" "user_data_sec" {
  template = file("userdata_sec.yaml")
}

resource "aws_instance" "bastion_instance_sec" {
  provider                    = aws.secondary
  for_each                    = aws_subnet.public_subnets_sec
  ami                         = data.aws_ami.ubuntu_sec.id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.bastion_sg_sec.id]
  subnet_id                   = aws_subnet.public_subnets_sec[each.key].id
  key_name                    = aws_key_pair.keypair_sec.key_name
  associate_public_ip_address = true

  tags = {
    Name = "bastion_${each.key}${var.environment_sec}"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "${self.private_ip} >> private_ips_bastion.txt"
      echo "${self.public_ip} >> public_ips_bastion.txt"
    EOT
  }
}
resource "aws_instance" "private_ec2_sec" {
  provider                    = aws.secondary
  for_each                    = aws_subnet.private_subnets_sec
  ami                         = data.aws_ami.ubuntu_sec.id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.bastion_sg_sec.id, aws_security_group.private_ec2_web_sg_sec.id]
  subnet_id                   = aws_subnet.private_subnets_sec[each.key].id
  key_name                    = aws_key_pair.keypair_sec.key_name
  user_data                   = data.template_file.user_data_sec.rendered
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile_sec.name

  provisioner "local-exec" {
    command = <<-EOT
      echo "${self.private_ip} >> private_ips_ec2.txt"
    EOT
  }

  tags = {
    Name = "ec2_${each.key}${var.environment_sec}"
  }
}


# ##############################################################################################################################
# #                             APPLICATION LOAD BALANCER + AUTO SCALING GROUP + CERTIFICATE MANAGER                           #
# ##############################################################################################################################


resource "aws_lb" "alb_sec" {
  provider                   = aws.secondary
  name                       = "alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb_sg_sec.id]
  enable_deletion_protection = false
  ip_address_type            = "ipv4"
  enable_http2               = true
  subnets = [aws_subnet.public_subnets_sec["public_subnet_1"].id,
  aws_subnet.public_subnets_sec["public_subnet_2"].id]

  tags = {
    Name = "alb${var.environment_sec}"
  }
}

resource "aws_lb_target_group" "ip_target_group_https_sec" {
  provider    = aws.secondary
  name        = "ip-target-group-https-sec"
  port        = 443
  protocol    = "HTTPS"
  target_type = "ip"
  vpc_id      = aws_vpc.vpc_sec.id

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
resource "aws_lb_target_group" "ip_target_group_http_sec" {
  provider    = aws.secondary
  name        = "ip-target-group-http-sec"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.vpc_sec.id

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

resource "aws_lb_target_group_attachment" "tg_attachment_https_sec" {
  provider         = aws.secondary
  for_each         = aws_instance.private_ec2_sec
  target_group_arn = aws_lb_target_group.ip_target_group_https_sec.arn
  target_id        = aws_instance.private_ec2_sec[each.key].private_ip
  port             = 443
}
resource "aws_lb_target_group_attachment" "tg_attachment_http_sec" {
  provider         = aws.secondary
  for_each         = aws_instance.private_ec2_sec
  target_group_arn = aws_lb_target_group.ip_target_group_http_sec.arn
  target_id        = aws_instance.private_ec2_sec[each.key].private_ip
  port             = 80
}

resource "aws_lb_listener" "http_listener_sec" {
  provider          = aws.secondary
  load_balancer_arn = aws_lb.alb_sec.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "redirect"
    target_group_arn = aws_lb_target_group.ip_target_group_http_sec.arn

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
resource "aws_lb_listener" "https_listener_sec" {
  provider          = aws.secondary
  load_balancer_arn = aws_lb.alb_sec.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = data.aws_acm_certificate.amazon_issued_sec.arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ip_target_group_https_sec.arn
  }
}

resource "aws_lb_listener_rule" "https_rule_sec" {
  provider     = aws.secondary
  listener_arn = aws_lb_listener.https_listener_sec.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ip_target_group_https_sec.arn
  }

  condition {
    host_header {
      values = ["www.fejzic37.com"]
    }
  }
}
resource "aws_lb_listener_rule" "http_rule_sec" {
  provider     = aws.secondary
  listener_arn = aws_lb_listener.http_listener_sec.arn
  priority     = 2

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ip_target_group_http_sec.arn
  }

  condition {
    host_header {
      values = ["www.fejzic37.com"]
    }
  }
}

data "aws_acm_certificate" "amazon_issued_sec" {
  provider    = aws.secondary
  domain      = var.subdomain_name
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

resource "aws_lb_listener_certificate" "alb_listener_certificate_sec" {
  provider        = aws.secondary
  listener_arn    = aws_lb_listener.https_listener_sec.arn
  certificate_arn = data.aws_acm_certificate.amazon_issued_sec.arn
}

resource "aws_launch_template" "launch_template_sec" {
  provider      = aws.secondary
  name          = "launch_template_sec"
  instance_type = var.instance_type
  key_name      = var.aws_keypair_name_sec
  image_id      = data.aws_ami.ubuntu_sec.id

  placement {
    availability_zone = data.aws_availability_zones.available_sec.id
  }

  vpc_security_group_ids = [aws_security_group.private_ec2_web_sg_sec.id]
  tags = {
    "Name" = "launch_template${var.environment_sec}"
  }
  user_data = filebase64("userdata_sec.yaml")
}

resource "aws_autoscaling_group" "asg_sec" {
  provider                  = aws.secondary
  name                      = "asg${var.environment_sec}"
  max_size                  = 1
  min_size                  = 0
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 0
  force_delete              = true
  vpc_zone_identifier = [aws_subnet.private_subnets_sec["private_subnet_1"].id,
  aws_subnet.private_subnets_sec["private_subnet_2"].id]
  launch_template {
    id      = aws_launch_template.launch_template_sec.id
    version = "$Latest"
  }
}


# ##############################################################################################################################
# #                                               S3 + IDENTITY AND ACCESS MANAGEMENT                                          #
# ##############################################################################################################################


resource "aws_s3_bucket" "ec2_bucket_sec" {
  provider = aws.secondary
  bucket   = "mfejzic37-secondary"
}

resource "aws_s3_bucket_public_access_block" "ec2_bucket_sec" {
  provider                = aws.secondary
  bucket                  = aws_s3_bucket.ec2_bucket_sec.bucket
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_object" "ec2_bucket_sec" {
  provider = aws.secondary
  depends_on = [
    aws_s3_bucket.ec2_bucket_sec
  ]
  bucket                 = aws_s3_bucket.ec2_bucket_sec.bucket
  key                    = "host/index.html"
  source                 = "./index.html"
  server_side_encryption = "AES256"
  content_type           = "text/html"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ec2_bucket_sec" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.ec2_bucket_sec.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "ec2_bucket_sec" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.ec2_bucket_sec.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_iam_role" "ec2_role_sec" {
  provider = aws.secondary
  name     = "web_server_role_sec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}
resource "aws_iam_policy" "s3_access_policy_sec" {
  provider    = aws.secondary
  name        = "s3_access_policy_sec"
  description = "IAM policy for EC2 to access S3"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ],
        Effect = "Allow",
        Resource = [
          "arn:aws:s3:::${var.bucket_name_sec}",
          "arn:aws:s3:::${var.bucket_name_sec}/host/index.html",
        ],
      },
    ],
  })
}

resource "aws_iam_policy_attachment" "access_to_s3_attachment_sec" {
  provider   = aws.secondary
  name       = "attachment"
  policy_arn = aws_iam_policy.s3_access_policy_sec.arn
  roles      = [aws_iam_role.ec2_role_sec.name]
}
resource "aws_iam_policy_attachment" "ec2_fetch_attachment_sec" {
  provider   = aws.secondary
  name       = "ec2 fetch"
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  roles      = [aws_iam_role.ec2_role_sec.name]
}

resource "aws_iam_instance_profile" "ec2_profile_sec" {
  provider = aws.secondary
  name     = "ec2_profile_sec"
  role     = aws_iam_role.ec2_role_sec.name
}


# ##############################################################################################################################
# #                                           CLOUDWATCH + SIMPLE NOTIFICATION SERVICE                                        #
# ##############################################################################################################################


resource "aws_cloudwatch_metric_alarm" "get_requests_S3_alarm_sec" {
  provider            = aws.secondary
  alarm_name          = "GetRequests_sec"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "GetRequests"
  namespace           = "AWS/S3"
  period              = 60
  statistic           = "Sum"
  unit                = "Count"
  threshold           = 3
  alarm_description   = "Alarm for S3 number of get requests exceeding threshold"
  alarm_actions       = [aws_sns_topic.sns_sec.arn] 
  dimensions = {
    BucketName = aws_s3_bucket.ec2_bucket_sec.bucket
  }

  tags = {
    "Name" = "cloudwatch_fetchS3${var.environment_sec}"
  }
}

resource "aws_sns_topic" "sns_sec" {
  provider = aws.secondary
  name     = "s3_request_sns"

  tags = {
    "Name" = "sns${var.environment_sec}"
  }
}
resource "aws_sns_topic_subscription" "sns_sec" {
  provider  = aws.secondary
  topic_arn = aws_sns_topic.sns_sec.arn
  protocol  = "email"
  endpoint  = "muhazic3@gmail.com"
}