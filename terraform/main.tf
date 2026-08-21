terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.57"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Environment = "assignment"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# ============================================================
# WEB VPC
# ============================================================

resource "aws_vpc" "web" {
  cidr_block           = var.web_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-web-vpc"
    Tier = "web"
  }
}

resource "aws_subnet" "web_public" {
  vpc_id                  = aws_vpc.web.id
  cidr_block              = var.web_public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-web-public-subnet"
    Tier = "web"
  }
}


# ============================================================
# APP VPC
# ============================================================

resource "aws_vpc" "app" {
  cidr_block           = var.app_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-app-vpc"
    Tier = "app"
  }
}

resource "aws_subnet" "app_public" {
  vpc_id                  = aws_vpc.app.id
  cidr_block              = var.app_public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-app-public-subnet"
    Tier = "app"
  }
}

resource "aws_subnet" "app_private" {
  vpc_id                  = aws_vpc.app.id
  cidr_block              = var.app_private_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-app-private-subnet"
    Tier = "app"
  }
}


# ============================================================
# DATA VPC
# ============================================================

resource "aws_vpc" "data" {
  cidr_block           = var.data_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-data-vpc"
    Tier = "data"
  }
}

resource "aws_subnet" "data_private_a" {
  vpc_id                  = aws_vpc.data.id
  cidr_block              = var.data_private_subnet_a_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-data-private-a"
    Tier = "data"
  }
}

resource "aws_subnet" "data_private_b" {
  vpc_id                  = aws_vpc.data.id
  cidr_block              = var.data_private_subnet_b_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-data-private-b"
    Tier = "data"
  }
}

# ============================================================
# WEB VPC INTERNET GATEWAY + ROUTING
# ============================================================

resource "aws_internet_gateway" "web" {
  vpc_id = aws_vpc.web.id

  tags = {
    Name = "${var.project_name}-web-igw"
  }
}

resource "aws_route_table" "web_public" {
  vpc_id = aws_vpc.web.id

  tags = {
    Name = "${var.project_name}-web-public-rt"
  }
}

resource "aws_route" "web_internet" {
  route_table_id         = aws_route_table.web_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.web.id
}

resource "aws_route_table_association" "web_public" {
  subnet_id      = aws_subnet.web_public.id
  route_table_id = aws_route_table.web_public.id
}


# ============================================================
# APP VPC INTERNET GATEWAY
# ============================================================

resource "aws_internet_gateway" "app" {
  vpc_id = aws_vpc.app.id

  tags = {
    Name = "${var.project_name}-app-igw"
  }
}


# ============================================================
# APP PUBLIC ROUTE TABLE
# ============================================================

resource "aws_route_table" "app_public" {
  vpc_id = aws_vpc.app.id

  tags = {
    Name = "${var.project_name}-app-public-rt"
  }
}

resource "aws_route" "app_public_internet" {
  route_table_id         = aws_route_table.app_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.app.id
}

resource "aws_route_table_association" "app_public" {
  subnet_id      = aws_subnet.app_public.id
  route_table_id = aws_route_table.app_public.id
}


# ============================================================
# SHARED NAT GATEWAY FOR APP PRIVATE SUBNET
# ============================================================

resource "aws_eip" "app_nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "app" {
  allocation_id = aws_eip.app_nat.id
  subnet_id     = aws_subnet.app_public.id

  depends_on = [
    aws_internet_gateway.app
  ]

  tags = {
    Name = "${var.project_name}-nat-gateway"
  }
}


# ============================================================
# APP PRIVATE ROUTE TABLE
# ============================================================

resource "aws_route_table" "app_private" {
  vpc_id = aws_vpc.app.id

  tags = {
    Name = "${var.project_name}-app-private-rt"
  }
}

resource "aws_route" "app_private_nat" {
  route_table_id         = aws_route_table.app_private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.app.id
}

resource "aws_route_table_association" "app_private" {
  subnet_id      = aws_subnet.app_private.id
  route_table_id = aws_route_table.app_private.id
}

# ============================================================
# WEB <-> APP VPC PEERING
# ============================================================

resource "aws_vpc_peering_connection" "web_app" {
  vpc_id      = aws_vpc.web.id
  peer_vpc_id = aws_vpc.app.id
  auto_accept = true

  tags = {
    Name = "${var.project_name}-web-app-peering"
  }
}

resource "aws_route" "web_to_app" {
  route_table_id            = aws_route_table.web_public.id
  destination_cidr_block    = var.app_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.web_app.id
}

resource "aws_route" "app_to_web" {
  route_table_id            = aws_route_table.app_private.id
  destination_cidr_block    = var.web_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.web_app.id
}


# ============================================================
# APP <-> DATA VPC PEERING
# ============================================================

resource "aws_vpc_peering_connection" "app_data" {
  vpc_id      = aws_vpc.app.id
  peer_vpc_id = aws_vpc.data.id
  auto_accept = true

  tags = {
    Name = "${var.project_name}-app-data-peering"
  }
}

resource "aws_route" "app_to_data" {
  route_table_id            = aws_route_table.app_private.id
  destination_cidr_block    = var.data_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.app_data.id
}


# ============================================================
# DATA VPC PRIVATE ROUTING
# ============================================================

resource "aws_route_table" "data_private" {
  vpc_id = aws_vpc.data.id

  tags = {
    Name = "${var.project_name}-data-private-rt"
  }
}

resource "aws_route" "data_to_app_route" {
  route_table_id            = aws_route_table.data_private.id
  destination_cidr_block    = var.app_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.app_data.id
}

resource "aws_route_table_association" "data_private_a" {
  subnet_id      = aws_subnet.data_private_a.id
  route_table_id = aws_route_table.data_private.id
}

resource "aws_route_table_association" "data_private_b" {
  subnet_id      = aws_subnet.data_private_b.id
  route_table_id = aws_route_table.data_private.id
}

# ============================================================
# WEB SECURITY GROUP
# ============================================================

resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "Security group for NimbusCart Web tier"
  vpc_id      = aws_vpc.web.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH for administration"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-web-sg"
  }
}


# ============================================================
# APP SECURITY GROUP
# ============================================================

resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Security group for NimbusCart App tier"
  vpc_id      = aws_vpc.app.id

  ingress {
    description     = "API traffic from Web tier"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  ingress {
    description = "SSH from Web VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.web_vpc_cidr]
  }

  egress {
    description = "Allow outbound traffic through NAT"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-app-sg"
  }
}


# ============================================================
# DATA / RDS SECURITY GROUP
# ============================================================

resource "aws_security_group" "data" {
  name        = "${var.project_name}-data-sg"
  description = "Security group for NimbusCart database"
  vpc_id      = aws_vpc.data.id

  ingress {
    description = "MySQL from App VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.app_vpc_cidr]
  }

  egress {
    description = "Allow database response traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-data-sg"
  }
}

# ============================================================
# ECR REPOSITORY
# ============================================================

resource "aws_ecr_repository" "api" {
  name                 = "${var.project_name}-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-api-ecr"
  }
}

# ============================================================
# APP EC2 IAM ROLE
# ============================================================

resource "aws_iam_role" "app" {
  name = "${var.project_name}-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-app-role"
  }
}

resource "aws_iam_role_policy_attachment" "app_ecr" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.project_name}-app-profile"
  role = aws_iam_role.app.name
}

# ============================================================
# RDS DB SUBNET GROUP
# ============================================================

resource "aws_db_subnet_group" "mysql" {
  name = "${var.project_name}-db-subnet-group"

  subnet_ids = [
    aws_subnet.data_private_a.id,
    aws_subnet.data_private_b.id
  ]

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# ============================================================
# RDS MYSQL DATABASE
# ============================================================

resource "aws_db_instance" "mysql" {
  identifier = "${var.project_name}-mysql"

  engine         = "mysql"
  engine_version = "8.4"

  instance_class        = var.db_instance_class
  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.mysql.name
  vpc_security_group_ids = [aws_security_group.data.id]

  publicly_accessible     = false
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 0

  tags = {
    Name = "${var.project_name}-mysql"
  }
}

# ============================================================
# EC2 KEY PAIR
# ============================================================

resource "aws_key_pair" "nimbuscart" {
  key_name   = "${var.project_name}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))

  tags = {
    Name = "${var.project_name}-key"
  }
}

# ============================================================
# APP EC2 INSTANCE
# ============================================================

resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.app_instance_type
  subnet_id              = aws_subnet.app_private.id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.nimbuscart.key_name

  associate_public_ip_address = false

  iam_instance_profile = aws_iam_instance_profile.app.name

  tags = {
    Name = "${var.project_name}-app-server"
    Tier = "app"
  }

}

# ============================================================
# WEB EC2 INSTANCE
# ============================================================

resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.web_instance_type
  subnet_id              = aws_subnet.web_public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = aws_key_pair.nimbuscart.key_name

  associate_public_ip_address = true

  tags = {
    Name = "${var.project_name}-web-server"
    Tier = "web"
  }
}

# ============================================================
# WEB TIER DEPLOYMENT
# ============================================================

resource "null_resource" "web_deployment" {
  depends_on = [
    aws_instance.web,
    aws_instance.app
  ]

  provisioner "file" {
    source      = "${path.module}/../app/frontend/index.html"
    destination = "/tmp/index.html"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(pathexpand("~/.ssh/id_ed25519"))
      host        = aws_instance.web.public_ip
    }
  }

  provisioner "file" {
    content = templatefile("${path.module}/../app/frontend/nginx.conf", {
      app_private_ip = aws_instance.app.private_ip
    })
    destination = "/tmp/nginx.conf"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(pathexpand("~/.ssh/id_ed25519"))
      host        = aws_instance.web.public_ip
    }
  }


  provisioner "file" {
    source      = "${path.module}/web_deploy.sh"
    destination = "/tmp/web_deploy.sh"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(pathexpand("~/.ssh/id_ed25519"))
      host        = aws_instance.web.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/web_deploy.sh",
      "sudo /tmp/web_deploy.sh"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(pathexpand("~/.ssh/id_ed25519"))
      host        = aws_instance.web.public_ip
    }
  }
}

# ============================================================
# APP TIER DEPLOYMENT
# ============================================================

resource "null_resource" "app_deployment" {
  depends_on = [
    aws_instance.web,
    aws_instance.app,
    aws_db_instance.mysql,
    aws_ecr_repository.api
  ]

  provisioner "file" {
    source      = "${path.module}/app_deploy.sh"
    destination = "/tmp/app_deploy.sh"

    connection {
      type                = "ssh"
      user                = "ec2-user"
      private_key         = file(pathexpand("~/.ssh/id_ed25519"))
      host                = aws_instance.app.private_ip
      bastion_host        = aws_instance.web.public_ip
      bastion_user        = "ec2-user"
      bastion_private_key = file(pathexpand("~/.ssh/id_ed25519"))
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/app_deploy.sh",
      "sudo ECR_REGISTRY='281525601825.dkr.ecr.ap-south-1.amazonaws.com' ECR_IMAGE='281525601825.dkr.ecr.ap-south-1.amazonaws.com/nimbuscart-api:1.2' DB_HOST='${aws_db_instance.mysql.address}' DB_NAME='${var.db_name}' DB_USER='${var.db_username}' DB_PASSWORD='${var.db_password}' /tmp/app_deploy.sh"
    ]

    connection {
      type                = "ssh"
      user                = "ec2-user"
      private_key         = file(pathexpand("~/.ssh/id_ed25519"))
      host                = aws_instance.app.private_ip
      bastion_host        = aws_instance.web.public_ip
      bastion_user        = "ec2-user"
      bastion_private_key = file(pathexpand("~/.ssh/id_ed25519"))
    }
  }
}
