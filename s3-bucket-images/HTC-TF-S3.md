# HOW TO CONFIG - Terraform File for S3 Buckets

## AWS

### 1. IAM
 Abra os serviços da AWS e vá para os serviços de IAM

### 2. Provedor de Identidade
 Clique em:
 - Identity providers
 - Add provider
 - OpenID Connect
 - providerURL: https://token.actions.githubusercontent.com
 - Audience: sts.amazonaws.com
 - Get thumbprint
 - Add provider

### 3. Criação de Funções
 Agora precisamos criar os roles. Vá em 'Roles' e siga esses passos:
 - Clique em Create role
 - Selecione Web Identity e escolha a URL que criamos
 - Selecione Audience e escolha a que criamos
 - Em GitHub organization/repositor, coloque o seu user do GitHub / nome do repositório 
 - Clique em Next

### 4. Adicionar Permissões
 Na tela de permissões, basta procurar AmazonS3FullAccess e marcar a caixa. Para produção não é muito recomendado, mas por enquanto ok, e então:
 - Clique em Next
 - Nomeie o role como GitHubActions-S3-Role
 - Revise e clique em Create role

### 5. Copiar o ARN da Role
 Após essa criação, clique no nome do role que você acabou de criar. Após isso, no topo da página, é possível ver o ARN. Basta copiar.

---

## GitHub

### 1. Abra e configura o repositório 
 Vá até o repositório i9-infrastructure e siga os seguintes passos:
 - selecione Settings
 - selecione Secrets and variables
 - selecione New repository secret
 - o Nome será AWS_ROLE_ARN
 - o Secret será a ARN que copiamos
 - Clique em Add secret

### 2. Rodar a Pipeline
 No repositório, acesse a aba 'Issues'
 - Clique em New issue
 - Título - nome base do bucket
 - Corpo - adicione uma por linha, no formato Chave=valor:
 <br /> Name=nome-do-bucket
 <br /> Environment=Production
 <br /> Owner=DevTeam
 - No menu lateral direito, clique em Labels e selecione s3-bucket
 - Clique em Submit new issue
 - Vá para a aba 'Actions' do repositório
 - Busque a pipeline em ação
 - Veja a execução!