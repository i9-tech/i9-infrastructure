# ===================================================================
# CONFIGURAÇÃO DO PROVIDER
# ===================================================================

provider "aws" {
  region = "us-east-1"
}


# ===================================================================
# VARIÁVEIS DE ENTRADA (INPUT VARIABLES)
# ===================================================================

variable "bucket_name" {
  description = "Nome base para o bucket S3."
  type        = string
}

variable "bucket_prefix" {
  description = "Prefixo para o nome do bucket (ex: prod, dev)."
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Tags a serem aplicadas no bucket."
  type        = map(string)
  default = {
    "ManagedBy" = "Terraform"
  }
}

variable "enable_versioning" {
  description = "Se verdadeiro, o versionamento do bucket será ativado."
  type        = bool
  default     = true
}


# ===================================================================
# FONTES DE DADOS (DATA SOURCES)
# ===================================================================

data "aws_caller_identity" "current" {}


# ===================================================================
# RECURSOS (RESOURCES)
# ===================================================================

resource "aws_s3_bucket" "generic_bucket" {
  bucket = "${var.bucket_prefix}-${var.bucket_name}-${data.aws_caller_identity.current.account_id}"

  # CUIDADO: Descomente e use 'true' apenas em ambientes de teste/desenvolvimento.
  # force_destroy = true

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "generic_bucket_versioning" {
  bucket = aws_s3_bucket.generic_bucket.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "generic_bucket_encryption" {
  bucket = aws_s3_bucket.generic_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "generic_bucket_pab" {
  bucket = aws_s3_bucket.generic_bucket.id

  # Bloqueia novas ACLs públicas
  block_public_acls       = false 

  # Bloqueia novas políticas de bucket públicas
  block_public_policy     = false 

  # Ignora ACLs públicas existentes
  ignore_public_acls      = false 

  # Restringe o acesso a este bucket se houver políticas públicas
  restrict_public_buckets = false 
}

resource "aws_s3_bucket_policy" "allow_public_read" {
  bucket = aws_s3_bucket.generic_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadForImages",
        Effect    = "Allow",
        Principal = "*",
        Action    = [
          "s3:GetObject"
        ],
        Resource = [
          "${aws_s3_bucket.generic_bucket.arn}/*" # Permite acesso a todos os objetos dentro do bucket
        ]
      }
    ]
  })
}

# ===================================================================
# SAÍDAS (OUTPUTS)
# ===================================================================

output "bucket_name" {
  description = "O nome final e completo do bucket S3 criado."
  value       = aws_s3_bucket.generic_bucket.id
}

output "bucket_arn" {
  description = "O ARN (Amazon Resource Name) do bucket S3."
  value       = aws_s3_bucket.generic_bucket.arn
}

output "bucket_domain_name" {
  description = "O nome de domínio do bucket, útil para acesso via URL."
  value       = aws_s3_bucket.generic_bucket.bucket_regional_domain_name
}