resource "aws_instance" "ec2_1" {
  ami           = "ami-0dba2cb6798deb6d8"
  instance_type = "t3.medium"

  root_block_device {
    volume_size = 300
    volume_type = "gp2"
  }

  tags = {
    Name = "Instance-t3-medium"
  }
}

resource "aws_instance" "ec2_2" {
  ami           = "ami-0dba2cb6798deb6d8"
  instance_type = "t3.large"

  root_block_device {
    volume_size = 5000
    volume_type = "gp2"
  }

  tags = {
    Name = "Instance-t3-large"
  }
}