# Dito — Desafio DevOps III

API HTTP em Go provisionada na AWS com Terraform, deployada em EKS via GitOps (Kustomize + GitHub Actions).

---

## Pré-requisitos locais

| Ferramenta | Versão mínima | Uso |
|---|---|---|
| AWS CLI | 2.x | Atualização do kubeconfig após apply |
| kubectl | 1.29+ | Inspeção do cluster |
| kustomize | 5.x | Renderização local dos manifests |
| Go | 1.26 | Build e testes da aplicação |

> **Terraform é executado exclusivamente pelo GitHub Actions** — não é necessário instalá-lo localmente.

---

## Como rodar localmente

### Aplicação

```bash
cd app
go test -v -race ./...      # testes
go run .                    # sobe na porta 8080
curl localhost:8080/healthz # OK
curl localhost:8080         # {"message":"Olá, DevOps!","env":"unknown","port":"8080"}
```

### Configuração de Secrets e Environments no GitHub

Antes de executar qualquer pipeline, configure o repositório:

**1. Secrets de repositório** — `Settings → Secrets and variables → Actions → New repository secret`

| Secret | Descrição |
|---|---|
| `AWS_ACCESS_KEY_ID` | Access key de uma IAM User/Role com permissão sobre EKS, ECR, RDS, IAM e Secrets Manager |
| `AWS_SECRET_ACCESS_KEY` | Secret key correspondente |
| `AWS_REGION` | Região AWS (ex.: `us-east-1`) |
| `AWS_ACCOUNT_ID` | ID numérico da conta AWS (usado para montar a URL do ECR) |
| `EKS_CLUSTER_NAME` | Nome do cluster após o primeiro apply (ex.: `dito-staging`) |

**2. Environments** — `Settings → Environments → New environment`

Crie dois environments: `staging` e `production`.

Em **production**, configure:
- **Required reviewers**: adicione os aprovadores obrigatórios antes do `apply-production`
- **Deployment branches**: selecione `Selected branches` → adicione a regra `main`

Em **staging**, nenhuma proteção adicional é necessária — o apply ocorre automaticamente após merge na `main`.

> Os secrets `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` e `AWS_REGION` são secrets de **repositório** (não de environment). Cada job os lê via `secrets.*` independentemente do environment declarado no job — o `environment:` no job serve para registrar o deployment no histórico do GitHub e escopá-lo para proteções de branch.

---

### Infraestrutura (Terraform)

Toda operação de infraestrutura é feita via GitHub Actions. Para acionar manualmente:

1. Acesse **Actions → Terraform IaC → Run workflow**
2. Selecione o ambiente (`staging` ou `production`)
3. Clique em **Run workflow**

O job `apply-production` fica pausado aguardando aprovação manual de um revisor cadastrado em **Settings → Environments → production → Required reviewers**.

Após o apply, configure o kubectl localmente:

```bash
aws eks update-kubeconfig --region us-east-1 --name dito-staging
# ou
aws eks update-kubeconfig --region us-east-1 --name dito-production
```

### Manifests Kubernetes

```bash
# renderizar sem aplicar (inspeção local)
kustomize build manifests/overlays/staging
kustomize build manifests/overlays/production
```

Os manifests são aplicados automaticamente pelo pipeline de app — commits na `main` com mudanças em `app/**` atualizam o overlay e o cluster via GitOps.

---

## Decisões técnicas

### EKS (e não GKE ou AKS)

Todos os outros recursos já são AWS (Secrets Manager, RDS, ECR, IAM). Usar EKS elimina a necessidade de um segundo provedor de cloud e permite IRSA — integração nativa entre Service Accounts do Kubernetes e IAM Roles sem credenciais de longa duração dentro do cluster. GKE teria Workload Identity equivalente, mas exigiria GCP para tudo o mais.

### IRSA (e não EKS Pod Identity)

O EKS Pod Identity Agent está provisionado como addon, mas o mecanismo de autenticação escolhido no `ExternalSecret` é JWT (IRSA) porque é suportado pelo operator `external-secrets` de forma estável em todos os provedores de Kubernetes, facilitando uma possível migração futura. Pod Identity é mais simples de configurar mas ainda é mais novo e com menos exemplos em produção.

### ExternalSecrets Operator (e não AWS SSM sync ou Sealed Secrets)

O ExternalSecrets sincroniza segredos do Secrets Manager como Kubernetes Secrets nativos, com refresh configurável (1h). Alternatives:
- **SSM Parameter Store sync**: mais barato, mas sem rotação automática integrada de senha de banco.
- **Sealed Secrets**: funciona offline mas exige gestão de chave de criptografia e não integra com o ciclo de vida do Secrets Manager.

O Secrets Manager com `manage_master_user_password = true` no RDS permite rotação automática de senha sem nenhuma alteração na aplicação — essa combinação justifica o custo maior do Secrets Manager frente ao SSM.

### Kustomize (e não Helm)

O único artefato variável entre ambientes é a tag da imagem e contagens de réplicas — não há templates complexos que justifiquem um chart Helm. Kustomize é nativo no kubectl, e o padrão `kustomize edit set image` encaixa diretamente no step de GitOps do CI sem dependências adicionais.

### Estratégia GitOps por diretório (e não por branch)

Branches de ambiente (`staging`, `production`) criam dois problemas: divergência de histórico entre branches e a necessidade de cherry-picks ou merges para promover mudanças. Com diretórios (`manifests/overlays/staging`, `manifests/overlays/production`), toda promoção é um diff visível em um único PR na `main`, e o histórico de ambos os ambientes fica no mesmo log do git.

O CI atualiza o overlay de staging automaticamente e, após aprovação do environment `production` no GitHub, atualiza o overlay de production. Um controller GitOps (ArgoCD ou FluxCD) faria a sincronização real com o cluster — ver seção de limitações.

### Nodes SPOT (e não ON_DEMAND)

Para um ambiente de demonstração, a economia é de ~90%: `t3.medium` SPOT custa ~$4–6/mês versus ~$35/mês ON_DEMAND. O risco de interrupção é mitigado por diversificação de famílias (`t3`, `t3a`) e tamanhos (`medium`, `large`). Em produção real, o ideal é um mix: node group ON_DEMAND mínimo para workloads críticos e SPOT para escala.

### State remoto com partial backend config

O Terraform não permite variáveis no bloco `backend`. A solução padrão é partial backend config: `backend.tf` declara bucket e região, e a chave do estado (`dito-demo/staging/terraform.tfstate` vs `dito-demo/production/terraform.tfstate`) é passada via `-backend-config=backend-<env>.hcl` no `terraform init`. Isso garante estados completamente isolados por ambiente sem duplicar código.

---

## O que faria com mais tempo

**GitOps controller real**: o projeto faz commits nos overlays mas nenhum controller sincroniza esses commits com o cluster. Adicionaria ArgoCD com `Application` configurado para auto-sync em staging e sync manual com `syncPolicy.automated` desativado em production. O `ApplicationSet` permitiria gerar as duas aplicações a partir de um único template.

**OIDC para o GitHub Actions**: hoje as credenciais AWS ficam como GitHub Secrets de longa duração. Substituiria por federação OIDC — o workflow assume uma IAM Role via token efêmero sem armazenar nenhuma chave.

**Módulos Terraform locais**: o `IaC/` atual é plano. Estruturaria em módulos locais (`modules/network`, `modules/compute`, `modules/data`, `modules/security`) para deixar explícitas as dependências entre camadas e facilitar reuso.

**VPC Endpoints**: sem endpoints para ECR, S3 e Secrets Manager, todo tráfego dos nodes sai pelo NAT Gateway — custo por GB e superfície de ataque desnecessária. Endpoints de interface/gateway eliminariam esse tráfego.

**Network Policies**: atualmente qualquer pod consegue falar com qualquer outro pod no cluster. Adicionaria `NetworkPolicy` com default-deny e allowlist explícita.

**Testes de infraestrutura**: `terratest` ou `tftest` para validar que os módulos criam os recursos esperados, especialmente as regras de security group do RDS.

**Checkov/tfsec no CI**: varredura estática do código Terraform para capturar más práticas de segurança (ex.: `endpoint_public_access = true`) antes do apply.

**`skip_final_snapshot` parametrizado**: hoje está `true` para ambos os ambientes. Em production deveria ser `false` para garantir snapshot antes de qualquer `destroy`.

---

## Riscos e limitações conhecidas

**Sem controller GitOps ativo**: o pipeline commita nos overlays mas não há ArgoCD ou FluxCD instalado no cluster para aplicar as mudanças. O estado real do cluster pode divergir do repositório sem que ninguém seja notificado.

**EKS API server público**: `endpoint_public_access = true` expõe a API do Kubernetes à internet. Qualquer credencial comprometida pode ser usada de qualquer IP. Em produção restringiria para os IPs do escritório e do runner de CI via `endpoint_public_access_cidrs`.

**Credenciais AWS de longa duração no CI**: `AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY` como GitHub Secrets são credenciais que não expiram. Um vazamento em logs ou em um fork malicioso seria crítico.

**Nodes SPOT podem ser interrompidos**: com `minReplicas: 2` e `topologySpreadConstraints`, a interrupção de um node derruba metade da capacidade antes do autoscaler reagir (~2 min). Workloads com SLA alto precisariam de ON_DEMAND como fallback.

**`skip_final_snapshot = true` em production**: se `terraform destroy` for executado em production por engano, o banco é destruído sem snapshot. Nenhum `deletion_protection = true` protege contra um `destroy -auto-approve` direto.

**Single NAT Gateway em staging**: se o NAT falhar, todo tráfego de saída dos nodes para ECR, Secrets Manager e internet cessa. Aceitável para staging, inaceitável para production (já configurado com `single_nat_gateway = false`).

**Sem monitoramento**: não há CloudWatch Alarms, métricas de aplicação (Prometheus/Grafana), tracing ou log aggregation configurados. Falhas silenciosas não seriam detectadas proativamente.

**Backup de 1 dia em staging**: suficiente para detectar erros introduzidos no mesmo dia, mas não cobre cenários onde a corrupção de dados é percebida dias depois.
