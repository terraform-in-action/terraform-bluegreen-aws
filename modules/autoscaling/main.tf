#create instance and autoscaling group and lb listeners
module "iam_instance_profile" {
  source  = "scottwinkler/iip/aws"
  actions = ["logs:*"]
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }
}

locals {
  html    = templatefile("${path.module}/server/index.html", { NAME = join("-", [var.group, var.app_version]), BG_COLOR = var.group })
  startup = templatefile("${path.module}/server/startup.sh", { HTML = local.html })
}

resource "aws_launch_template" "webserver" {
  name_prefix   = var.base.namespace
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  user_data     = base64encode(local.startup)
  key_name      = var.ssh_keypair
  iam_instance_profile {
    name = module.iam_instance_profile.name
  }
  vpc_security_group_ids = [var.base.sg.webserver]
  tags = {
    ResourceGroup = var.base.namespace
  }
}

resource "aws_autoscaling_group" "webserver" {
  name     = "${var.base.namespace}-${var.group}-asg"
  min_size = 3
  max_size = 3
  //vpc_zone_identifier = var.base.vpc.private_subnets
  vpc_zone_identifier = var.base.vpc.public_subnets
  target_group_arns   = var.group == "green" ? var.base.target_group_arns.green : var.base.target_group_arns.blue
  launch_template {
    id      = aws_launch_template.webserver.id
    version = aws_launch_template.webserver.latest_version
  }
  tag {
    key                 = "ResourceGroup"
    value               = var.base.namespace
    propagate_at_launch = true
  }
  tag {
    key                 = "Name"
    value               = "${var.base.namespace}-${var.group}"
    propagate_at_launch = true
  }
}

