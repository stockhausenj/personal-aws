terraform {
  required_providers { aws = {
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
  default_tags {
    tags = {
      env = "test"
    }
  }
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
  count = var.create_instance ? 1 : 0

  ami           = data.aws_ami.ubuntu_24.id
  instance_type = "t2.large"
  key_name      = "macos"

  root_block_device {
    volume_size = 20
  }

  lifecycle {
    ignore_changes = [
      ami
    ]
  }

  tags = {
    Name     = "ubuntu-24"
    test     = "tfcloud"
    schedule = var.instance_schedule
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "github_actions_role" {
  name = "GitHubActionsRole"

  # aka trust relationship policy
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Federated": aws_iam_openid_connect_provider.github.arn
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:stockhausenj/*:*"
        },
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_lambda_policy" {
  role = aws_iam_role.github_actions_role.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "lambda:*"
      ],
      "Resource": "*"
    }]
  })
}

resource "aws_iam_role_policy" "github_ecr_all_policy" {
  role = aws_iam_role.github_actions_role.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:List*",
        "ecr:Describe*"
      ],
      "Resource": "*"
    }]
  })
}

resource "aws_iam_role_policy" "github_ecr_repo_policy" {
  role = aws_iam_role.github_actions_role.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "ecr:*"
      ],
      "Resource": [
        aws_ecr_repository.personal_test.arn,
      ]
    }]
  })
}

resource "aws_ecr_repository" "personal_test" {
  name                 = "personal/test"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
