# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Visão Geral

Desafio técnico DevOps III — plataforma de demonstração na AWS composta por três camadas independentes:

- **`app/`** — servidor HTTP em Go (único arquivo `main.go`)
- **`IaC/`** — infraestrutura AWS via Terraform
- **`manifests/`** — manifests Kubernetes gerenciados com Kustomize

## Comandos

### Aplicação Go (`app/`)

```bash
cd app
go test -v -race -coverprofile=coverage.out ./...   # testes com race detector
go tool cover -func=coverage.out                    # relatório de cobertura
go build -o server .                                # build local
go run .                                            # execução local (porta 8080)
```

Ferramentas de análise estática usadas no CI (instalar manualmente se necessário):

```bash
go install golang.org/x/vuln/cmd/govulncheck@latest && govulncheck ./...
go install honnef.co/go/tools/cmd/staticcheck@latest && staticcheck ./...
go mod verify && go mod tidy && git diff --exit-code go.mod go.sum
```

### Infraestrutura Terraform (`IaC/`)

O Makefile executa o Terraform dentro de um container Docker. Requer `.env.aws` com `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` e `AWS_DEFAULT_REGION`.

```bash
cd IaC
make terraform-init    # inicializa módulos e backend S3
make terraform-plan    # gera plano de execução
make terraform-apply   # aplica infraestrutura
make terraform-destroy # destrói infraestrutura
make terraform-fmt     # formata arquivos .tf
make terraform-sh      # shell interativo no container Terraform
```

Após o apply, configurar kubectl:

```bash
aws eks update-kubeconfig --region us-east-1 --name dito-demo
```

### Manifests Kubernetes (`manifests/`)

```bash
kustomize build manifests/overlays/dev   # renderiza manifests do ambiente dev
kustomize build manifests/overlays/prod  # renderiza manifests do ambiente prod
kubectl apply -k manifests/overlays/dev  # aplica no cluster (requer kubeconfig)
```

## Arquitetura

### Fluxo CI/CD (GitOps)

O pipeline `app.yml` é acionado em push para `main` com mudanças em `app/**`:

1. **Análise paralela**: lint do Dockerfile (hadolint), testes Go, govulncheck, gosec, staticcheck, `go mod verify`, Gitleaks
2. **Build**: imagem Docker multi-stage (`golang:1.26-alpine` → `scratch`) publicada no ECR (`dito-demo`) com tag = SHA do commit
3. **Trivy scan**: varredura de CVEs HIGH/CRITICAL na imagem publicada
4. **GitOps commit**: atualiza `manifests/overlays/dev/kustomization.yaml` e depois `manifests/overlays/prod/kustomization.yaml` com a nova tag da imagem via `kustomize edit set image`

O pipeline `iac.yml` é acionado em mudanças em `IaC/**`: valida (fmt + validate) em PRs; plan + apply em push para `main`.

### Infraestrutura AWS (Terraform)

Todos os recursos ficam em `us-east-1` sob o nome `dito-demo`. O state do Terraform é remoto no S3 (`jonatas-silva-terraform-backend`) com lock via DynamoDB.

| Recurso | Módulo/Recurso TF | Detalhe |
|---|---|---|
| VPC | `terraform-aws-modules/vpc` | CIDR `10.0.0.0/16`, 3 AZs, NAT Gateway único |
| EKS | `terraform-aws-modules/eks` v21 | Kubernetes 1.33, node group SPOT (t3/t3a.medium/large), 1–3 nós |
| RDS | `terraform-aws-modules/rds` | PostgreSQL 16, `db.t4g.micro`, senha gerenciada pelo Secrets Manager |
| ECR | `terraform-aws-modules/ecr` | Repositório `dito-demo`, lifecycle: expira untagged após 14 dias |
| IAM IRSA | `terraform-aws-modules/iam//iam-role-for-service-accounts-eks` | Role vinculada ao ServiceAccount `dito-demo-sa` nos namespaces `dev` e `prod` |
| Secrets Manager | `aws_secretsmanager_secret` | Secret `dito-demo/app-secrets` para segredos de runtime |

### Kubernetes / Kustomize

**Base** (`manifests/base/`): Deployment, Service, HPA, ServiceAccount e ExternalSecret compartilhados.

**Overlays**:
- `dev`: prefixo `dev-`, 1 réplica, HPA 1–3, sem `namePrefix` em prod
- `prod`: 2 réplicas base, HPA 2–10

**External Secrets**: o `SecretStore` aponta para o AWS Secrets Manager via IRSA (JWT do ServiceAccount). O `ExternalSecret` sincroniza `dito-demo/app-secrets` como K8s Secret `app-secrets` (refresh 1h). O Deployment injeta esses segredos via `envFrom.secretRef`.

**IRSA**: o ServiceAccount `dito-demo-sa` carrega a annotation `eks.amazonaws.com/role-arn` apontando para a role IAM criada pelo Terraform, que tem permissão apenas de leitura no Secrets Manager.

### Aplicação Go

Servidor HTTP mínimo sem dependências externas (stdlib apenas). Endpoints:
- `GET /` — retorna JSON `{"message", "env", "port"}`
- `GET /healthz` — retorna `200 OK` (usado pelas probes do Kubernetes)

Aguarda 10 segundos no startup (simula warmup), configurável pelas variáveis `APP_PORT` (padrão `8080`) e `APP_ENV`.

## Secrets necessários no GitHub Actions

`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `AWS_ACCOUNT_ID`, `EKS_CLUSTER_NAME`
