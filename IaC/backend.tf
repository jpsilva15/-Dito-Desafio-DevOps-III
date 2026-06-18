terraform {
  backend "s3" {
    bucket  = "jonatas-silva-terraform-backend"
    region  = "sa-east-1"
    encrypt = true
    # key é fornecida via: terraform init -backend-config=backend-<env>.hcl
  }
}
