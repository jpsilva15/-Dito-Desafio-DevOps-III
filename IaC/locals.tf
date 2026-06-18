data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "current" {}

locals {
  name   = "dito-demo"
  region = "us-east-1"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  db_name     = "ditodemo"
  db_username = "ditoadmin"

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
