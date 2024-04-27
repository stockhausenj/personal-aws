terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  cloud {
    organization = "jay-stockhausen"

    workspaces {
      name = "personal-aws"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "private" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "tfcloud"
    sentinel = ""
  }
}

data "aws_ami" "ubuntu_24" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "ubuntu_24" {
  ami           = data.aws_ami.ubuntu_24.id
  instance_type = "t2.large"
  key_name      = "macos"

  root_block_device {
    volume_size = 20
  }

  tags = {
    Name     = "ubuntu-24"
    test     = "tfcloud"
    schedule = "stop-at-10"
  }
}
