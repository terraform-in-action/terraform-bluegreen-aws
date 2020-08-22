resource "random_string" "rand" {
  length  = 24
  special = false
  upper   = false
}

locals {
  namespace = var.namespace != "" ? substr(join("-", [var.namespace, random_string.rand.result]), 0, 24) : random_string.rand.result
}

resource "aws_resourcegroups_group" "resourcegroups_group" {
  name = "${local.namespace}-group"

  resource_query {
    query = <<-JSON
      {
        "ResourceTypeFilters": [
          "AWS::AllSupported"
        ],
        "TagFilters": [
          {
            "Key": "ResourceGroup",
            "Values": ["${local.namespace}"]
          }
        ]
      }
    JSON
  }
}
# create vpc and load balancer and resource group
data "aws_availability_zones" "available" {}

module "vpc" {
  source             = "terraform-aws-modules/vpc/aws"
  version            = "2.17.0"
  name               = "${local.namespace}-vpc"
  cidr               = "10.0.0.0/16"
  azs                = data.aws_availability_zones.available.names
  private_subnets    = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = true
}

module "lb_sg" {
  source = "scottwinkler/sg/aws"
  vpc_id = module.vpc.vpc_id
  ingress_rules = [{
    port        = 80
    cidr_blocks = ["0.0.0.0/0"]
  }]
}

module "webserver_sg" {
  source = "scottwinkler/sg/aws"
  vpc_id = module.vpc.vpc_id
  ingress_rules = [
    {
      port            = 8080
      security_groups = [module.lb_sg.security_group.id]
    },
    {
      port        = 22
      cidr_blocks = ["10.0.0.0/16"]
    }
  ]
}

resource "aws_lb" "lb" {
  name            = "${local.namespace}-lb"
  subnets         = module.vpc.public_subnets
  security_groups = [module.lb_sg.security_group.id]
  tags = {
    ResourceGroup = local.namespace
  }
}

resource "aws_lb_target_group" "blue_target_group" {
  name        = "${local.namespace}-blue"
  port        = 8080
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = module.vpc.vpc_id
  tags = {
    ResourceGroup = local.namespace
  }
  //health_check
}

resource "aws_lb_target_group" "green_target_group" {
  name        = "${local.namespace}-green"
  port        = 8080
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = module.vpc.vpc_id
  tags = {
    ResourceGroup = local.namespace
  }
  //health_check
}

resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = var.production == "green" ? aws_lb_target_group.green_target_group.arn : aws_lb_target_group.blue_target_group.arn
  }
}


resource "aws_lb_listener_rule" "lb_listener_rule" {
  listener_arn = aws_lb_listener.lb_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = var.production == "green" ? aws_lb_target_group.blue_target_group.arn : aws_lb_target_group.green_target_group.arn
  }

  condition {
    path_pattern {
      values = ["/stg/*"]
    }
  }
}
