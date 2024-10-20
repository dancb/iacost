provider "aws" {
  region = "us-west-1"  # Cambia la región según tus necesidades
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
  name        = "allow_ssh"
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

# Crear la instancia EC2 de tipo t2.micro
resource "aws_instance" "my_ec2" {
  ami           = "ami-0c55b159cbfafe1f0"  # ID de la AMI de Amazon Linux 2 (puedes cambiarla)
  instance_type = "t2.micro"               # Tipo de instancia

  # Asocia el Key Pair generado a la instancia
  key_name = aws_key_pair.deployed_key.key_name

  # Asocia el Security Group
  vpc_security_group_ids = [aws_security_group.my_security_group.id]

  # Tags (opcional)
  tags = {
    Name = "MyEC2Instance"
  }

  # Root block device configuration (opcional)
  root_block_device {
    volume_size = 8  # Tamaño del disco en GB
    volume_type = "gp2"  # Tipo de volumen (gp2, io1, etc.)
  }
}
