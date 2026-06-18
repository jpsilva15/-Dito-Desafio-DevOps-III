data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "current" {}

locals {
  name   = "dito-${var.environment}"
  region = var.region

  vpc_cidr = var.vpc_cidr
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  db_name     = "ditodemo"
  db_username = "ditoadmin"

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}
