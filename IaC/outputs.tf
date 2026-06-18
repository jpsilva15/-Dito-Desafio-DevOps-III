################################################################################
# EKS
################################################################################

output "cluster_name" {
  description = "Nome do cluster EKS"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint da API do cluster EKS"
  value       = module.eks.cluster_endpoint
}

################################################################################
# ECR
################################################################################

output "ecr_repository_url" {
  description = "URL do repositório ECR"
  value       = module.ecr.repository_url
}

################################################################################
# RDS
################################################################################

output "db_endpoint" {
  description = "Endpoint de conexão do RDS PostgreSQL"
  value       = module.db.db_instance_endpoint
  sensitive   = true
}

output "db_secret_arn" {
  description = "ARN do secret gerado pelo RDS (credenciais do banco)"
  value       = module.db.db_instance_master_user_secret_arn
}

################################################################################
# Secrets Manager
################################################################################

output "app_secret_arn" {
  description = "ARN do secret de runtime da aplicação"
  value       = aws_secretsmanager_secret.app.arn
}

################################################################################
# IAM / IRSA
################################################################################

output "workload_irsa_role_arn" {
  description = "ARN do IAM Role para o Service Account do workload"
  value       = module.workload_irsa.iam_role_arn
}

################################################################################
# Terraform State
################################################################################

output "terraform_state_bucket" {
  description = "Nome do bucket S3 para o state do Terraform"
  value       = module.s3_terraform_state.s3_bucket_id
}
