terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# chave SSH
provider "tls" {}

# ==============================
#  1. Rede (VPC e Subnets)   
# ==============================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/24" # CIDR
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "i9-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/25" # CIDR 
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "i9-subnet-publica"
  }
}

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.128/25" # CIDR
  map_public_ip_on_launch = false
  availability_zone       = "us-east-1a"

  tags = {
    Name = "i9-subnet-privada"
  }
}

# ==============================
# 2. Roteamento e Conectividade
# ==============================

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "i9-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "i9-route-table-publica"
  }
}

resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "i9-nat"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "i9-route-table-privada"
  }
}

resource "aws_route_table_association" "private_rta" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_rt.id
}


# ==============================
# 3. Segurança (SSH Key e Security Groups)
# ==============================

resource "tls_private_key" "deployer_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "ssh_key_pem" {
  content         = tls_private_key.deployer_key.private_key_pem
  filename        = "i9-key.pem"
  file_permission = "0600"
}

resource "aws_key_pair" "deployer" {
  key_name   = "i9-key"
  public_key = tls_private_key.deployer_key.public_key_openssh

  tags = {
    Name = "i9-key"
  }
}

resource "aws_security_group" "public_sg" {
  name        = "i9-sg-publico"
  description = "Allow SSH and HTTP access"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS"
  }

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    description = "Allow Redis access from Spring Boot SG"
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow public HTTP"
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow all traffic from other instances in this SG"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "i9-sg-publico"
  }
}

resource "aws_security_group" "private_sg" {
  name        = "i9-sg-privado"
  description = "Allow internal traffic and SSH from public"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id]
    description     = "Allow SSH from Public SG (Bastion)"
  }

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    description = "Allow Redis access from Spring Boot SG"
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow public HTTP"
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow all traffic from other instances in this SG"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "i9-sg-privado"
  }
}

# ==============================
# 4. Instâncias EC2
# ==============================

data "aws_ami" "ubuntu_lts" {
  most_recent = true
  owners      = ["099720109477"] # Canonical - Proprietário das AMIs Ubuntu

  filter {
    name = "name"
    # Filtra pela imagem Ubuntu Server 22.04 LTS (Jammy Jellyfish)
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "public_instance" {
  count = 1

  ami             = data.aws_ami.ubuntu_lts.id
  instance_type   = "t2.large"
  key_name        = aws_key_pair.deployer.key_name
  subnet_id       = aws_subnet.public.id
  security_groups = [aws_security_group.public_sg.id]

  tags = {
    Name = "i9-ec2-publica-${count.index + 1}"
  }

  provisioner "file" {
    # Origem: O arquivo PEM gerado localmente pelo Terraform.
    source      = local_file.ssh_key_pem.filename # 'i9-key.pem'
    destination = "/home/ubuntu/i9-key.pem"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.deployer_key.private_key_pem
      host        = self.public_ip
      timeout     = "5m"
    }
  }

  provisioner "remote-exec" {
    inline = [
      # Garante que as permissões do arquivo PEM sejam seguras (somente leitura pelo proprietário)
      "chmod 400 /home/ubuntu/i9-key.pem",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.deployer_key.private_key_pem
      host        = self.public_ip
      timeout     = "5m"
    }
  }
}

resource "aws_instance" "private_instances" {
  count = 3

  ami             = data.aws_ami.ubuntu_lts.id
  instance_type   = "t2.large"
  key_name        = aws_key_pair.deployer.key_name
  subnet_id       = aws_subnet.private.id
  security_groups = [aws_security_group.private_sg.id]

  tags = {
    Name = "i9-ec2-privada-${count.index + 1}"
  }
}

# ==============================
# 5. Outputs
# ==============================

output "ip_instancia_publica" {
  description = "IP público da instância pública"
  value       = aws_instance.public_instance[0].public_ip
}

output "ips_instancias_privadas" {
  description = "IPs privados das 3 instâncias privadas"
  value       = aws_instance.private_instances[*].private_ip
}

output "conectar_ec2_publica" {
  description = "Comando para conectar na instância pública (bastion)"
  value       = "ssh -i 'i9-key.pem' ubuntu@ec2-${aws_instance.public_instance[0].public_ip}.compute-1.amazonaws.com"
}

output "conectar_ec2_privada" {
  description = "Exemplo de como pular para uma instância privada (rode após conectar no bastion)"
  value       = "ssh -i 'i9-key.pem' ubuntu@${aws_instance.private_instances[0].private_ip}"
}
