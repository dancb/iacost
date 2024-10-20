# Esta instancia solo la uso para ejecutar el codigo Python

provider "aws" {
  region = "us-east-1"  # Región us-east-1 (Norte de Virginia)
}

# Genera un par de claves SSH
resource "tls_private_key" "ec2_key_pair" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Crear el Key Pair en AWS
resource "aws_key_pair" "deployed_key" {
  key_name   = "my-generated-key"  # Nombre del par de claves en AWS
  public_key = tls_private_key.ec2_key_pair.public_key_openssh
}

# Guarda la clave privada localmente
resource "local_file" "private_key" {
  filename = "${path.module}/config/my-generated-key.pem"
  content  = tls_private_key.ec2_key_pair.private_key_pem
  file_permission = "0400"  # Permisos seguros para la clave privada
}

# Security group para la instancia EC2 (opcional)
resource "aws_security_group" "my_security_group" {
  name        = "costiac_allow_ssh"
  description = "Allow SSH inbound traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Permitir SSH desde cualquier IP (modificar para mayor seguridad)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Permitir todo el tráfico de salida
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Crear la instancia EC2 
resource "aws_instance" "my_ec2" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t3.medium" 

  # Asocia el Key Pair generado a la instancia
  key_name = aws_key_pair.deployed_key.key_name

  # Asocia el Security Group
  vpc_security_group_ids = [aws_security_group.my_security_group.id]

  # Configura el script user_data para instalar Python y dependencias y generar logs
  user_data = <<-EOF
              #!/bin/bash

              # Archivo de log
              LOG_FILE="/var/log/user-data.log"

              # Redirigir toda la salida a este archivo de log
              exec > >(tee -a \$LOG_FILE /var/log/cloud-init-output.log) 2>&1

              echo "User Data script started at $(date)" | tee -a \$LOG_FILE

              # Actualizar paquetes del sistema
              echo "Updating system packages..." | tee -a \$LOG_FILE
              sudo yum update -y | tee -a \$LOG_FILE

              # Instalar Python3
              echo "Installing Python3..." | tee -a \$LOG_FILE
              sudo yum install -y python3 | tee -a \$LOG_FILE

              # Instalar pip (si es necesario)
              echo "Installing pip..." | tee -a \$LOG_FILE
              sudo yum install -y python3-pip | tee -a \$LOG_FILE

              # Instalar boto3 (la biblioteca de AWS para Python)
              echo "Installing boto3..." | tee -a \$LOG_FILE
              pip3 install boto3 | tee -a \$LOG_FILE

              # Instalar JQ (para manejar JSON en bash)
              echo "Installing JQ..." | tee -a \$LOG_FILE
              sudo yum install -y jq | tee -a \$LOG_FILE

              echo "User Data script finished at $(date)" | tee -a \$LOG_FILE
              EOF

  # Tags (opcional)
  tags = {
    Name = "costiac-estimator"
  }

  # Root block device configuration (opcional)
  root_block_device {
    volume_size = 8  # Tamaño del disco en GB
    volume_type = "gp2"  # Tipo de volumen (gp2, io1, etc.)
  }
}
