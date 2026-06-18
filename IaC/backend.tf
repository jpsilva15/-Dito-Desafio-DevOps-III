terraform {
  backend "s3" {
    bucket  = ""
    key     = "dito-prova/terraform.tfstate"
    region  = "sa-east-1"
    encrypt = true
  }
}
