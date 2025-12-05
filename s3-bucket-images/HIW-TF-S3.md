# HOW IT WORKS - Terraform File for S3 Buckets

## Arquivo `main.tf`

### 1. Configuração do provider
 Essa parte define o provedor (que no nosso caso é AWS) e a região.
 É uma boa prática definir a região via variáveis ou configuração do backend, mas por padrão usamos a **us-east-1**.

---

### 2. Variáveis de entrada
 Definimos os parâmetros para tornar nosso módulo flexível e reutilizável. Nele temos diversos campos de variáveis, como os abaixo:
 - `bucket_name`: define o nome principal para nosso bucket, como 'imagens-publicas', 'imagens-pratos', 'notas-fiscais', etc.
 - `bucket_prefix`: definição de para identificarmos o ambiente, podendo ser dev, prod, geral...
 - `tags`: mapeamento para organizar e controlar custos na AWS
 - `enable_versioning`: habilita ou desabilita o versionamento dos buckets

---

### 3. Fontes de dados
 Utilizado para buscarmos as informações da nossa conta AWS. Importante lembrar que muitas dessas credenciais são temporárias, então estão sempre sendo renovadas. Temos a função que obtem o ID da conta AWS atual para auxiliar na criação do bucket único.

---

### 4. Recursos
 Onde a infraestrutura será criada e gerenciada pelo Terraform. Configuramos quatro principais recursos:
 - `aws_s3_bucket` `generic_bucket`: recurso principal o bucket. ele constrói o nome do bucket com maior probabilidade de ser único globalmente a partir de variáveis do prefíxo (segmento do bucket, como 'bucket-images'), o nome (variando de acordo com funcionalidade) e ID atual da conta AWS conectada. Dentro desse recurso, temos uma função que força a exclusão do bucket mesmo que ele não esteja vazio, sendo indicado a usar apenas em ambientes de teste/desenvolvimento.
 - `aws_s3_bucket_versioning` `generic_bucket_versioning`: configuração do versionamento para o bucket. ele utiliza a variável de versionamento para decidir qual o status de versionamento.
 - `aws_s3_bucket_server_side_encryption_configuration` `generic_bucket_encryption`: gera a criptografica padrão com o server-side encryption, utilizando um algoritmo de criptografia gerenciado pela AWS.
 - `aws_s3_bucket_public_access_block` `generic_bucket_pab`: bloco de segurança para impedir acesso público acidental, podendo variar caso deseje hospedar aplicações estáticas no bucket. Nele, bloqueamos _ACLs públicas_, _Novas políticas de bucket públicas_, _Ignora ACLs públicas existentes_ e _Restringe o acesso ao bucket se houver políticas públicas_

---

### 5. Saídas
 Informações que serão exibidas no terminal do github actions após a execução do comando **terraform apply**. Temos os logs:
 - `bucket_name`: nome final e completo do bucket criado
 - `bucket_arn`: Amazon Resource Name do bucket
 - `bucket_domain_name`: nome de domínio do bucket para acesso via URL

---

## Arquivo workflow `provision-s3-bucket-creation.yaml`

## 1. Gatilho
 Primeiro temos o gatilho acionado sempre que uma issue é aberta no github

---

## 2. Permissões
 Permissões necessárias para que o arquivo execute:
 - `id-token`: Autenticação com a AWS via OIDC  
 - `contents`: Baixa o código
 - `issues`: Posta comentários na issue

---

## 3. Trabalhos
 Aqui temos alguns blocos principais, começando pelo identificador do job, e então o nome de exibição do job e onde ele rodará, além de um identificador de que ele só rodará se a issue possuir a label "s3-bucket". Além disso, temos os seguintes passos, todos com seus respectivos nomes:
 <br /> 3.1. Baixa o cpodigo do repositório
 <br /> 3.2. Configura as credenciais da AWS de forma segura
 <br /> 3.3. Instala e configura o terraform na pipeline
 <br /> 3.4. Extrai as variáveis do título e corpo da issue
 <br /> 3.5. Inicializa o Terraform
 <br /> 3.6. Valida a sintaxe do código do Terraform
 <br /> 3.7. Cria o plano de execução do Terraform
 <br /> 3.8. Aplica o Terraform para criar a infraestrutura configurada
 <br /> 3.9. (Opcional) Adiciona um comentário na issue informando sucesso
 <br /> 3.10.(Opcional) Adiciona um comentário na issue informando falha