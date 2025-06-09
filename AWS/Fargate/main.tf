##############################################################################################################################
#                                                           US-EAST-1                                                        #
##############################################################################################################################
##############################################################################################################################
#                                      Virtual Private Cloud + Network Access Control List                                   #
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
  cidr_block     = var.allow_all_cidr 
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
#                                             Subnet + Gateways + Route Tables                                               #
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
#                                                     Security Groups                                                        #
##############################################################################################################################


# Create security group for load balancer
resource "aws_security_group" "alb_sg" {
  provider    = aws.primary
  name        = "alb_sg"
  description = "Allow http inbound for load balancer"
  vpc_id      = aws_vpc.vpc.id

  ingress = [{
    cidr_blocks      = [var.allow_all_cidr]
    description      = "allow http in"
    from_port        = 80
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = []
    self             = true
    to_port          = 80
  }]

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allow_all_cidr]
  }

  tags = {
    "Name" = "alb_sg${var.environment}"
  }
}

# Create security group for the fargate applications
resource "aws_security_group" "fargate_sg" {
  provider    = aws.primary
  name        = "fargate_sg"
  description = "Allow inbound traffic from load balancer only"
  vpc_id      = aws_vpc.vpc.id
  depends_on  = [aws_security_group.alb_sg]

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.allow_all_cidr]
  }

  tags = {
    "Name" = "fargate_sg${var.environment}"
  }
}


##############################################################################################################################
#                                        Application Load Balancer + Target Group                                            #
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
resource "aws_lb_target_group" "target_group" {
  provider    = aws.primary
  name        = "ip-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.vpc.id

  health_check {
    path                = "/"
    port                = 80
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

# Add listener on port 80 and forward to ip target group
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}

# Create rule to match incoming requests based on host header and forward to target group
resource "aws_lb_listener_rule" "my_listener_rule" {
  listener_arn = aws_lb_listener.listener.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }

  condition {
    host_header {
      values = [var.subdomain_name, var.domain_name]
    }
  }
}


##############################################################################################################################
#                                          ECS Service + Cluster + Task Definition                                           #
##############################################################################################################################


# Create cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  provider = aws.primary
  name     = "main_cluster"

  tags = {
    Name = "main_cluster_${var.environment}"
  }
}

# Describe launch group and containers with task definition
resource "aws_ecs_task_definition" "task_definition" {
  depends_on = [
    aws_ecs_cluster.ecs_cluster
  ]

  provider                 = aws.primary
  family                   = "fargate_app"
  execution_role_arn       = aws_iam_role.ecs_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  memory                   = 512
  cpu                      = 256

  container_definitions = jsonencode([
    {
      name      = "app_container"
      image     = "876606637086.dkr.ecr.us-east-1.amazonaws.com/mfejzic:latest"
      essential = true

      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]

      environment = [
        {
          name  = "ddb_table",
          value = aws_dynamodb_table.ddb.name
        }
      ]
    },
  ])

  tags = {
    Name = "task_definition${var.environment}"
  }
}

# Create service to run tasks based on task definition and launch type / confiugre in private subnets
resource "aws_ecs_service" "ecs_service" {
  provider         = aws.primary
  name             = "main_service"
  cluster          = aws_ecs_cluster.ecs_cluster.id
  task_definition  = aws_ecs_task_definition.task_definition.arn
  launch_type      = "FARGATE"
  platform_version = "LATEST"
  desired_count    = 2
  depends_on       = [aws_iam_role_policy.ecr_role_policy]

  network_configuration {
    security_groups = [aws_security_group.fargate_sg.id]

    subnets = [
      aws_subnet.private_subnets["private_subnet_1"].id,
      aws_subnet.private_subnets["private_subnet_2"].id
    ]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = var.ContainerName
    container_port   = 80
  }

  tags = {
    Name = "ecs_service${var.environment}"
  }
}


##############################################################################################################################
#                                          DynamoDB + Identity and Access Management                                         #
##############################################################################################################################


#Create dynamodb table for container details
resource "aws_dynamodb_table" "ddb" {
  provider       = aws.primary
  name           = "fargate_ddb"
  billing_mode   = "PROVISIONED"
  read_capacity  = 10
  write_capacity = 1
  hash_key       = "ContainerName"

  attribute {
    name = "ContainerName"
    type = "S"
  }

  ttl {
    attribute_name = "TimeToExist"
    enabled        = true
  }

  tags = {
    Name = "fargate_ddb${var.environment}"
  }
}

# Add container details to the table
resource "aws_dynamodb_table_item" "ddb" {
  provider   = aws.primary
  table_name = aws_dynamodb_table.ddb.name
  hash_key   = "ContainerName"

  item = <<ITEM
{
  "ContainerName": {"S": "${var.ContainerName}"},
  "ContainerImage": {"S": "${var.ContainerName}"}
}
ITEM
}

# Define an IAM role for ecs tasks
resource "aws_iam_role" "ecs_role" {
  provider = aws.primary
  name     = "ecs_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Allow access to the ecr repository to grab the image / attach to ecs role
resource "aws_iam_role_policy" "ecr_role_policy" {
  provider = aws.primary
  name     = "ecr_role_policy"
  role     = aws_iam_role.ecs_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = "ecr:*",
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}


# Define an IAM policy with full DynamoDB access
resource "aws_iam_policy" "ddb_policy" {
  provider    = aws.primary
  name        = "ddb_iam"
  description = "Full access to DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = "dynamodb:*",
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

# Attach the database policy to the ecs role
resource "aws_iam_policy_attachment" "ddb_attachment" {
  provider   = aws.primary
  name       = "dynamodb-access"
  policy_arn = aws_iam_policy.ddb_policy.arn
  roles      = [aws_iam_role.ecs_role.name]
}

# ------------------------------------- Create and attach load balancer policy to ecs role -------------------------------------#

# Define IAM policy for the load balancer to access the ecs service
resource "aws_iam_policy" "alb_policy" {
  provider    = aws.primary
  name        = "alb_policy"
  description = "Policy to allow ECS to use ALB"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "elasticloadbalancing:*",
        ],
        Effect   = "Allow",
        Resource = aws_lb.alb.arn
      }
    ]
  })
}

# Attach the load balancer policy to the ecs role
resource "aws_iam_role_policy_attachment" "alb_attachment" {
  provider   = aws.primary
  policy_arn = aws_iam_policy.alb_policy.arn
  role       = aws_iam_role.ecs_role.name
}


##############################################################################################################################
#                                           Cloudwatch + Simple Notification Service                                         #
##############################################################################################################################


# Create CloudWatch alarm for ECS memory utilization
resource "aws_cloudwatch_metric_alarm" "ecs_memory_alarm" {
  provider            = aws.primary
  alarm_name          = "ECSMemoryUtilizationAlarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 10
  alarm_description   = "High Memory Utilization for ECS Tasks/Containers"
  alarm_actions       = [aws_sns_topic.sns.arn]

  dimensions = {
    ServiceName = aws_ecs_service.ecs_service.name
  }

  tags = {
    "Name" = "ecs_memory_alarm${var.environment}"
  }
}

# Create Cloudwatch for ecs cpu utilization
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_alarm" {
  provider            = aws.primary
  alarm_name          = "ECSCPUUtilizationAlarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 10
  alarm_description   = "High CPU Utilization for ECS Tasks/Containers"
  alarm_actions       = [aws_sns_topic.sns.arn]

  dimensions = {
    ServiceName = aws_ecs_service.ecs_service.name
  }

  tags = {
    "Name" = "ecs_cpu_alarm${var.environment}"
  }
}

# Create CloudWatch alarm for ALB request count
resource "aws_cloudwatch_metric_alarm" "alb_request_count_alarm" {
  provider            = aws.primary
  alarm_name          = "ALBRequestCountAlarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "High ALB Request Count"
  alarm_actions       = [aws_sns_topic.sns.arn]

  dimensions = {
    LoadBalancer = aws_lb.alb.id
  }

  tags = {
    "Name" = "alb_request_count_alarm${var.environment}"
  }
}

# Consolidate all alarms into one SNS topic for alarm notifications
resource "aws_sns_topic" "sns" {
  provider = aws.primary
  name     = "receive_metrics"

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


# Refer to current hosted zone in aws console
data "aws_route53_zone" "hosted_zone" {
  name         = var.domain_name
  private_zone = false
}

# Create primary and secondary alias with failover policy / secondary points to us-west-2 load balancer
resource "aws_route53_record" "primary_alias" {
  //provider = aws.primary
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  name    = "www.${data.aws_route53_zone.hosted_zone.name}"
  type    = "A"

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
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  name    = "www.${data.aws_route53_zone.hosted_zone.name}"
  type    = "A"

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
  fqdn              = var.subdomain_name
  port              = 80
  type              = "HTTPS"
  request_interval  = 30
  failure_threshold = 3
  tags = {
    Name = "primary_health_check"
  }
}
resource "aws_route53_health_check" "secondary" {
  //provider          = aws.primary
  fqdn              = var.subdomain_name
  port              = 80
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
#                                      Virtual Private Cloud + Network Access Control List                                   #
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
  cidr_block     = var.allow_all_cidr #
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


##############################################################################################################################
#                                             Subnet + Gateways + Route Tables                                               #
##############################################################################################################################


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
  provider   = aws.secondary
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw_sec]
  tags = {
    Name = "eip${var.environment_sec}"
  }
}
resource "aws_eip" "eip_2_sec" {
  provider   = aws.secondary
  domain     = "vpc"
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
  vpc_id   = aws_vpc.vpc_sec.id
  provider = aws.secondary

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


##############################################################################################################################
#                                                     Security Groups                                                        #
##############################################################################################################################


resource "aws_security_group" "alb_sg_sec" {
  provider    = aws.secondary
  name        = "alb_sg"
  description = "Allow http inbound for load balancer"
  vpc_id      = aws_vpc.vpc_sec.id

  ingress = [{
    cidr_blocks      = [var.allow_all_cidr]
    description      = "allow http in"
    from_port        = 80
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = []
    self             = true
    to_port          = 80
  }]

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allow_all_cidr]
  }

  tags = {
    "Name" = "alb_sg${var.environment_sec}"
  }
}

resource "aws_security_group" "fargate_sg_sec" {
  provider    = aws.secondary
  name        = "fargate_sg"
  description = "Allow inbound traffic from load balancer only"
  vpc_id      = aws_vpc.vpc_sec.id
  depends_on  = [aws_security_group.alb_sg_sec]

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg_sec.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.allow_all_cidr]
  }

  tags = {
    "Name" = "fargate_sg${var.environment_sec}"
  }
}


##############################################################################################################################
#                                        Application Load Balancer + Target Group                                            #
##############################################################################################################################


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

resource "aws_lb_target_group" "target_group_sec" {
  provider    = aws.secondary
  name        = "ip-target-group-sec"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.vpc_sec.id

  health_check {
    path                = "/"
    port                = 80
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "listener_sec" {
  provider    = aws.secondary
  load_balancer_arn = aws_lb.alb_sec.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group_sec.arn
  }
}

resource "aws_lb_listener_rule" "my_listener_rule_sec" {
  provider    = aws.secondary
  listener_arn = aws_lb_listener.listener_sec.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group_sec.arn
  }

  condition {
    host_header {
      values = [var.subdomain_name, var.domain_name]
    }
  }
}


##############################################################################################################################
#                                          ECS Service + Cluster + Task Definition                                           #
##############################################################################################################################


resource "aws_ecs_cluster" "ecs_cluster_sec" {
  provider = aws.secondary
  name     = "main_cluster_sec"

  tags = {
    Name = "main_cluster_${var.environment_sec}"
  }
}

resource "aws_ecs_task_definition" "task_definition_sec" {
  depends_on = [
    aws_ecs_cluster.ecs_cluster_sec
  ]

  provider                 = aws.secondary
  family                   = "fargate_app"
  execution_role_arn       = aws_iam_role.ecs_role_sec.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  memory                   = 512
  cpu                      = 256

  container_definitions = jsonencode([
    {
      name      = "app_container"
      image     = "876606637086.dkr.ecr.us-east-1.amazonaws.com/mfejzic:latest"
      essential = true

      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]

      environment = [
        {
          name  = "ddb_table",
          value = aws_dynamodb_table.ddb_sec.name
        }
      ]
    },
  ])

  tags = {
    Name = "task_definition${var.environment_sec}"
  }
}

resource "aws_ecs_service" "ecs_service_sec" {
  provider         = aws.secondary
  name             = "main_service_sec"
  cluster          = aws_ecs_cluster.ecs_cluster_sec.id
  task_definition  = aws_ecs_task_definition.task_definition_sec.arn
  launch_type      = "FARGATE"
  platform_version = "LATEST"
  desired_count    = 2
  depends_on       = [aws_iam_role_policy.ecr_role_policy_sec]

  network_configuration {
    security_groups = [aws_security_group.fargate_sg_sec.id]

    subnets = [
      aws_subnet.private_subnets_sec["private_subnet_1"].id,
      aws_subnet.private_subnets_sec["private_subnet_2"].id
    ]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group_sec.arn
    container_name   = var.ContainerName
    container_port   = 80
  }

  tags = {
    Name = "ecs_service${var.environment_sec}"
  }
}


##############################################################################################################################
#                                          DynamoDB + Identity and Access Management                                         #
##############################################################################################################################


resource "aws_dynamodb_table" "ddb_sec" {
  provider       = aws.secondary
  name           = "fargate_ddb_sec"
  billing_mode   = "PROVISIONED"
  read_capacity  = 10
  write_capacity = 1
  hash_key       = "ContainerName"

  attribute {
    name = "ContainerName"
    type = "S"
  }

  ttl {
    attribute_name = "TimeToExist"
    enabled        = true
  }

  tags = {
    Name = "fargate_ddb${var.environment_sec}"
  }
}

resource "aws_dynamodb_table_item" "ddb_sec" {
  provider   = aws.secondary
  table_name = aws_dynamodb_table.ddb_sec.name
  hash_key   = "ContainerName"

  item = <<ITEM
{
  "ContainerName": {"S": "${var.ContainerName}"},
  "ContainerImage": {"S": "${var.ContainerName}"}
}
ITEM
}

resource "aws_iam_role" "ecs_role_sec" {
  provider = aws.secondary
  name     = "ecs_role_sec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecr_role_policy_sec" {
  provider = aws.secondary
  name     = "ecr_role_policy_sec"
  role     = aws_iam_role.ecs_role_sec.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = "ecr:*",
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "ddb_policy_sec" {
  provider    = aws.secondary
  name        = "ddb_iam_sec"
  description = "Full access to DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = "dynamodb:*",
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "ddb_attachment_sec" {
  provider   = aws.secondary
  name       = "dynamodb-access_sec"
  policy_arn = aws_iam_policy.ddb_policy_sec.arn
  roles      = [aws_iam_role.ecs_role_sec.name]
}

# ------------------------------------- Create and attach load balancer policy to ecs role -------------------------------------#

resource "aws_iam_policy" "alb_policy_sec" {
  provider    = aws.secondary
  name        = "alb_policy_sec"
  description = "Policy to allow ECS to use ALB"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "elasticloadbalancing:*",
        ],
        Effect   = "Allow",
        Resource = aws_lb.alb_sec.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "alb_attachment_sec" {
  provider   = aws.secondary
  policy_arn = aws_iam_policy.alb_policy_sec.arn
  role       = aws_iam_role.ecs_role_sec.name
}


##############################################################################################################################
#                                           Cloudwatch + Simple Notification Service                                         #
##############################################################################################################################


resource "aws_cloudwatch_metric_alarm" "ecs_memory_alarm_sec" {
  provider            = aws.secondary
  alarm_name          = "ECSMemoryUtilizationAlarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 10
  alarm_description   = "High Memory Utilization for ECS Tasks/Containers"
  alarm_actions       = [aws_sns_topic.sns_sec.arn]

  dimensions = {
    ServiceName = aws_ecs_service.ecs_service_sec.name
  }

  tags = {
    "Name" = "ecs_memory_alarm${var.environment_sec}"
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_alarm_sec" {
  provider            = aws.secondary
  alarm_name          = "ECSCPUUtilizationAlarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 10
  alarm_description   = "High CPU Utilization for ECS Tasks/Containers"
  alarm_actions       = [aws_sns_topic.sns_sec.arn]

  dimensions = {
    ServiceName = aws_ecs_service.ecs_service_sec.name
  }

  tags = {
    "Name" = "ecs_cpu_alarm${var.environment_sec}"
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_request_count_alarm_sec" {
  provider            = aws.secondary
  alarm_name          = "ALBRequestCountAlarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "High ALB Request Count"
  alarm_actions       = [aws_sns_topic.sns_sec.arn]

  dimensions = {
    LoadBalancer = aws_lb.alb_sec.id
  }

  tags = {
    "Name" = "alb_request_count_alarm${var.environment_sec}"
  }
}

resource "aws_sns_topic" "sns_sec" {
  provider = aws.secondary
  name     = "receive_metrics"

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

// new resume
// post