resource "aws_secretsmanager_secret" "app" {
  name        = "${local.name}/app-secrets"
  description = "Secrets de runtime da aplicação ${local.name}"

  tags = local.tags
}
