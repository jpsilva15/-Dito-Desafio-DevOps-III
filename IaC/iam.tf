module "workload_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.name}-workload"

  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = [
        "dev:${local.name}-sa",
        "prod:${local.name}-sa",
      ]
    }
  }

  role_policy_arns = {
    workload = aws_iam_policy.workload.arn
  }

  tags = local.tags
}

resource "aws_iam_policy" "workload" {
  name        = "${local.name}-workload"
  description = "Permissões mínimas: leitura de secrets no Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.app.arn,
        ]
      }
    ]
  })
}
