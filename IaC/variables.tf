variable "environment" {
  description = "Nome do ambiente (staging ou production)"
  type        = string
  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "O ambiente deve ser 'staging' ou 'production'."
  }
}

variable "region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "single_nat_gateway" {
  description = "Usar um único NAT Gateway (economiza custo em ambientes não-produtivos)"
  type        = bool
  default     = true
}

variable "rds_instance_class" {
  description = "Classe de instância do RDS"
  type        = string
  default     = "db.t4g.micro"
}

variable "rds_multi_az" {
  description = "Habilitar Multi-AZ no RDS"
  type        = bool
  default     = false
}

variable "rds_backup_retention_period" {
  description = "Período de retenção de backups do RDS em dias (0 desabilita)"
  type        = number
  default     = 0
}

variable "rds_deletion_protection" {
  description = "Habilitar proteção contra exclusão do RDS"
  type        = bool
  default     = false
}

variable "eks_node_instance_types" {
  description = "Tipos de instância para o node group do EKS"
  type        = list(string)
  default     = ["t3.medium", "t3a.medium", "t3.large", "t3a.large"]
}

variable "eks_node_min_size" {
  description = "Número mínimo de nós no node group"
  type        = number
  default     = 1
}

variable "eks_node_max_size" {
  description = "Número máximo de nós no node group"
  type        = number
  default     = 3
}

variable "eks_node_desired_size" {
  description = "Número desejado de nós no node group"
  type        = number
  default     = 1
}
