variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "nimbuscart"
}

variable "web_vpc_cidr" {
  description = "CIDR block for the Web VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "app_vpc_cidr" {
  description = "CIDR block for the App VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "data_vpc_cidr" {
  description = "CIDR block for the Data VPC"
  type        = string
  default     = "10.30.0.0/16"
}

variable "web_public_subnet_cidr" {
  description = "Web public subnet"
  type        = string
  default     = "10.10.1.0/24"
}

variable "app_public_subnet_cidr" {
  description = "App public subnet for NAT Gateway"
  type        = string
  default     = "10.20.1.0/24"
}

variable "app_private_subnet_cidr" {
  description = "App private subnet"
  type        = string
  default     = "10.20.2.0/24"
}

variable "data_private_subnet_a_cidr" {
  description = "Data private subnet in AZ A"
  type        = string
  default     = "10.30.1.0/24"
}

variable "data_private_subnet_b_cidr" {
  description = "Data private subnet in AZ B"
  type        = string
  default     = "10.30.2.0/24"
}

variable "db_name" {
  description = "MySQL database name"
  type        = string
  default     = "nimbuscart"
}

variable "db_username" {
  description = "MySQL master username"
  type        = string
  default     = "nimbus"
}

variable "db_password" {
  description = "MySQL master password"
  type        = string
  sensitive   = true
  default     = "nimbuspass"
}

variable "db_instance_class" {
  description = "RDS MySQL instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "app_instance_type" {
  description = "EC2 instance type for App tier"
  type        = string
  default     = "t3.micro"
}

variable "web_instance_type" {
  description = "EC2 instance type for Web tier"
  type        = string
  default     = "t3.micro"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key used by Terraform"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}
