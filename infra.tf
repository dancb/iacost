resource "aws_instance" "ec2_1" {
  ami           = "ami-0dba2cb6798deb6d8"
  instance_type = "c4.8xlarge"

  root_block_device {
    volume_size = 300
    volume_type = "gp2"
  }

  tags = {
    Name = "Instance-C4-8xlarge"
  }
}

resource "aws_instance" "ec2_2" {
  ami           = "ami-0dba2cb6798deb6d8"
  instance_type = "t2.medium"

  root_block_device {
    volume_size = 5000
    volume_type = "gp2"
  }

  tags = {
    Name = "Instance-T2-Medium"
  }
}