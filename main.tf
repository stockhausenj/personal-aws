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
  default_tags {
    tags = {
      env = "test"
    }
  }
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_subnet" "general_private_subnet_1" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.96.0/20"
  availability_zone       = "us-east-1d"
  map_public_ip_on_launch = false

  tags = {
    kind = "private"
  }
}

resource "aws_subnet" "general_private_subnet_2" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.112.0/20"
  availability_zone       = "us-east-1f"
  map_public_ip_on_launch = false

  tags = {
    kind = "private"
  }
}

resource "aws_eip" "nat_gateway_eip" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = "subnet-38939134"
}

resource "aws_route_table" "general_private_route_table" {
  vpc_id = data.aws_vpc.default.id
}

resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.general_private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "general_private_subnet_1" {
  subnet_id      = aws_subnet.general_private_subnet_1.id
  route_table_id = aws_route_table.general_private_route_table.id
}

resource "aws_route_table_association" "general_private_subnet_2" {
  subnet_id      = aws_subnet.general_private_subnet_2.id
  route_table_id = aws_route_table.general_private_route_table.id
}

resource "aws_vpc" "private" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name     = "tfcloud"
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
    "Version" : "2012-10-17",
    "Statement" : [{
      "Effect" : "Allow",
      "Principal" : {
        "Federated" : aws_iam_openid_connect_provider.github.arn
      },
      "Action" : "sts:AssumeRoleWithWebIdentity",
      "Condition" : {
        "StringLike" : {
          "token.actions.githubusercontent.com:sub" : "repo:stockhausenj/*:*"
        },
        "StringEquals" : {
          "token.actions.githubusercontent.com:aud" : "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_lambda_policy" {
  role = aws_iam_role.github_actions_role.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Effect" : "Allow",
      "Action" : [
        "lambda:*"
      ],
      "Resource" : "*"
    }]
  })
}

resource "aws_iam_role_policy" "github_ecr_all_policy" {
  role = aws_iam_role.github_actions_role.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Effect" : "Allow",
      "Action" : [
        "ecr:GetAuthorizationToken",
        "ecr:List*",
        "ecr:Describe*"
      ],
      "Resource" : "*"
    }]
  })
}

resource "aws_iam_role_policy" "github_ecr_repo_policy" {
  role = aws_iam_role.github_actions_role.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Effect" : "Allow",
      "Action" : [
        "ecr:*"
      ],
      "Resource" : "*"
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

resource "aws_ecr_lifecycle_policy" "personal_test" {
  repository = aws_ecr_repository.personal_test.name

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 1 image",
            "selection": {
                "tagStatus": "untagged",
                "countType": "imageCountMoreThan",
                "countNumber": 1
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}
