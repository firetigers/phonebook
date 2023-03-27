data "aws_vpc" "selected" {
  default = true
}

data "aws_subnets" "pb-subnets" {
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
    filter {
    name = "tag:Name"
    values = ["default*"]
  }
}

data "aws_ami" "amazon-linux-2" {
  owners = ["amazon"]
  most_recent = true
  filter {
    name = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

data "template_file" "phonebook" {
  template = file("user-data.sh")
  vars = {
    user-data-git-token = var.git-token
    user-data-git-name = var.git-name
  }
}

resource "aws_launch_template" "asg-lt" {
  name = "phonebook-lt"

  image_id = data.aws_ami.amazon-linux-2.id
  instance_type = "t2.micro"
  key_name = var.key-name
  vpc_security_group_ids = [aws_security_group.server-sg.id]
  user_data = base64encode(data.template_file.phonebook.rendered)
  depends_on = [github_repository_file.dbendpoint]
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "Web Server of Phonebook App"
    }
  }
}

resource "aws_alb_target_group" "app-lb-tg" {
  name = "phonebook-lb-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = data.aws_vpc.selected.id
  target_type = "instance"

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 3

  }
}

resource "aws_alb" "app-lb" {
  name = "phonebook-lb-tf"
  ip_address_type = "ipv4"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb-sg.id]
  subnets = data.aws_subnets.pb-subnets.ids
}

resource "aws_alb_listener" "app-listener" {
  load_balancer_arn = aws_alb.app-lb.arn
  port = 80
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_alb_target_group.app-lb-tg.arn
  }
}

resource "aws_autoscaling_group" "app-asg" {
  max_size = 3
  min_size = 1
  desired_capacity = 1
  name = "phonebook-asg"
  health_check_grace_period = 300
  health_check_type = "ELB"
  target_group_arns = [aws_alb_target_group.app-lb-tg.arn]
  vpc_zone_identifier = aws_alb.app-lb.subnets
  launch_template {
    id = aws_launch_template.asg-lt.id
    version = aws_launch_template.asg-lt.latest_version
  }
}

resource "aws_db_instance" "db-server" {
  instance_class = "db.t2.micro"
  allocated_storage = 20
  vpc_security_group_ids = [aws_security_group.db-sg.id]
  allow_major_version_upgrade = false
  auto_minor_version_upgrade = true
  backup_retention_period = 0
  identifier = "phonebook-app-db"
  db_name = "phonebook"
  engine = "mysql"
  engine_version = "8.0.28"
  username = "admin"
  password = "Oliver_1"
  monitoring_interval = 0
  multi_az = false
  port = 3306
  publicly_accessible = false
  skip_final_snapshot = true

}

resource "github_repository_file" "dbendpoint" {
  content = aws_db_instance.db-server.address
  file = "dbserver.endpoint"
  repository = "phonebook"
  overwrite_on_create = true
  branch = "main"
}

data "aws_route53_zone" "selected" {
  name         = var.hosted-zone
}

resource "aws_route53_record" "phonebook" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "phonebook.${var.hosted-zone}"
  type    = "A"

  alias {
    name                   = aws_alb.app-lb.dns_name
    zone_id                = aws_alb.app-lb.zone_id
    evaluate_target_health = true
  }
}