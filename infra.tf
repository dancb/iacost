# Aqui van todos los recursos de prueba que la calculadora analizará.

# Crear una VPC
resource "aws_vpc" "costiac_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "costiac-vpc"
  }
}

# Crear subnets públicas
resource "aws_subnet" "costiac_public_subnet_1" {
  vpc_id                  = aws_vpc.costiac_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    Name = "costiac-public-subnet-1"
  }
}

resource "aws_subnet" "costiac_public_subnet_2" {
  vpc_id                  = aws_vpc.costiac_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"
  tags = {
    Name = "costiac-public-subnet-2"
  }
}

# Crear una gateway de internet
resource "aws_internet_gateway" "costiac_igw" {
  vpc_id = aws_vpc.costiac_vpc.id
  tags = {
    Name = "costiac-igw"
  }
}

# Crear una tabla de enrutamiento para las subnets públicas
resource "aws_route_table" "costiac_public_route_table" {
  vpc_id = aws_vpc.costiac_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.costiac_igw.id
  }

  tags = {
    Name = "costiac-public-route-table"
  }
}

# Asignar la tabla de enrutamiento a las subnets públicas
resource "aws_route_table_association" "costiac_route_assoc_subnet_1" {
  subnet_id      = aws_subnet.costiac_public_subnet_1.id
  route_table_id = aws_route_table.costiac_public_route_table.id
}

resource "aws_route_table_association" "costiac_route_assoc_subnet_2" {
  subnet_id      = aws_subnet.costiac_public_subnet_2.id
  route_table_id = aws_route_table.costiac_public_route_table.id
}

# Crear un grupo de seguridad que permita SSH y acceso SSM
resource "aws_security_group" "costiac_sg" {
  vpc_id = aws_vpc.costiac_vpc.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Permitir SSH desde cualquier IP
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Permitir tráfico HTTPS para el agente SSM
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "costiac-sg"
  }
}

# Crear un volumen EBS de 100GB para la primera instancia
resource "aws_ebs_volume" "costiac_ebs_volume" {
  availability_zone = "us-east-1a"
  size              = 100
  tags = {
    Name = "costiac-ebs-volume"
  }
}

# Crear el sistema de archivos EFS para la segunda instancia
resource "aws_efs_file_system" "costiac_efs" {
  tags = {
    Name = "costiac-efs"
  }
}

resource "aws_efs_mount_target" "costiac_efs_mount_target" {
  file_system_id  = aws_efs_file_system.costiac_efs.id
  subnet_id       = aws_subnet.costiac_public_subnet_2.id
  security_groups = [aws_security_group.costiac_sg.id]
}

# Primera instancia EC2 con EBS
resource "aws_instance" "costiac_instance_1" {
  ami           = "ami-0c02fb55956c7d316"  # Amazon Linux 2 AMI para us-east-1
  instance_type = "c4.8xlarge" #"t2.micro"
  subnet_id     = aws_subnet.costiac_public_subnet_1.id
  security_groups = [aws_security_group.costiac_sg.id]

  root_block_device {
    volume_size = 8  # Tamaño predeterminado para el volumen raíz
  }

  ebs_block_device {
    device_name           = "/dev/sdh"   # El nombre del dispositivo en la instancia
    volume_size           = 500          # Tamaño del volumen en GB
    delete_on_termination = true         # Eliminar el volumen cuando la instancia se termine
  }

  # Instalar el agente SSM
  user_data = <<-EOF
              #!/bin/bash
              yum install -y amazon-ssm-agent
              systemctl enable amazon-ssm-agent
              systemctl start amazon-ssm-agent
              EOF

  tags = {
    Name = "costiac-instance-1"
  }
}

# Segunda instancia EC2 con EFS
resource "aws_instance" "costiac_instance_2" {
  ami           = "ami-0c02fb55956c7d316"  # Amazon Linux 2 AMI para us-east-1
  instance_type = "c4.8xlarge" #"t2.micro"
  subnet_id     = aws_subnet.costiac_public_subnet_2.id
  security_groups = [aws_security_group.costiac_sg.id]

  root_block_device {
    volume_size = 8  # Tamaño predeterminado para el volumen raíz
  }

  # Montar el sistema de archivos EFS
  user_data = <<-EOF
              #!/bin/bash
              yum install -y amazon-ssm-agent amazon-efs-utils
              systemctl enable amazon-ssm-agent
              systemctl start amazon-ssm-agent
              mkdir /mnt/efs
              mount -t efs ${aws_efs_file_system.costiac_efs.id}:/ /mnt/efs
              EOF

  tags = {
    Name = "costiac-instance-2"
  }
}
