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

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "general" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.large"

  tags = {
    Name = "general"
    test = "tfcloud"
  }
}