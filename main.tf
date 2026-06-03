terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.global_settings.aws_region
}

resource "random_string" "security_group_suffix" {
  length  = 4
  upper   = false
  special = false
}

locals {
  # If compute_nodes is provided, use it. Otherwise preserve legacy behavior.
  compute_nodes_effective = length(var.compute_nodes) > 0 ? var.compute_nodes : {
    for idx in range(var.instance_count) :
    format("%s-%02d", var.name_prefix, idx + 1) => {
      instance_type       = var.instance_type
      data_disk_1_size_gb = 0
      tags                = {}
    }
  }

  compute_nodes_with_data_disk = {
    for node_name, node in local.compute_nodes_effective :
    node_name => node
    if node.data_disk_1_size_gb > 0
  }
}

data "aws_ami" "windows_2022" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "windows_vm_sg" {
  name        = "${var.global_settings.security_group_name}-${random_string.security_group_suffix.result}"
  description = "Allow trusted IP and local network full access"
  vpc_id      = var.global_settings.vpc_id

  ingress {
    description = "Allow all TCP ports from trusted source"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.global_settings.allowed_ingress_cidr]
  }

  ingress {
    description = "Allow all UDP ports from trusted source"
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = [var.global_settings.allowed_ingress_cidr]
  }

  ingress {
    description = "Allow all ICMP from trusted source"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.global_settings.allowed_ingress_cidr]
  }

  ingress {
    description = "Allow all inbound traffic from local network"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.global_settings.local_network_cidr]
  }

  egress {
    description = "Allow all outbound traffic to local network"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.global_settings.local_network_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.global_settings.common_tags,
    {
      Name = "${var.global_settings.security_group_name}-${random_string.security_group_suffix.result}"
    }
  )
}

resource "aws_instance" "windows_vm" {
  for_each = local.compute_nodes_effective

  ami                    = data.aws_ami.windows_2022.id
  instance_type          = each.value.instance_type
  subnet_id              = var.global_settings.subnet_id
  vpc_security_group_ids = [aws_security_group.windows_vm_sg.id]
  key_name               = var.global_settings.key_pair_name

  user_data = templatefile("${path.module}/userdata.ps1.tftpl", {
    ansible_username = var.global_settings.ansible_username
    ansible_password = var.global_settings.ansible_password
  })

  tags = merge(
    var.global_settings.common_tags,
    each.value.tags,
    {
      Name = each.key
    }
  )
}

resource "aws_ebs_volume" "data_disk_1" {
  for_each = local.compute_nodes_with_data_disk

  availability_zone = aws_instance.windows_vm[each.key].availability_zone
  size              = each.value.data_disk_1_size_gb
  type              = "gp3"

  tags = merge(
    var.global_settings.common_tags,
    each.value.tags,
    {
      Name = "${each.key}-data-1"
    }
  )
}

resource "aws_volume_attachment" "data_disk_1" {
  for_each = local.compute_nodes_with_data_disk

  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data_disk_1[each.key].id
  instance_id = aws_instance.windows_vm[each.key].id
}
