#provider
provider "aws" {
  region  = "ap-south-1"
  profile = "mrtiwari"
}


#creating key pair
resource "tls_private_key" "task-1-pri-key" { 
  algorithm   = "RSA"
  rsa_bits = 2048
}


resource "aws_key_pair" "task-1-key" {
  depends_on = [ tls_private_key.task-1-pri-key, ]
  key_name   = "task-1-key"
  public_key = tls_private_key.task-1-pri-key.public_key_openssh
}

#creating security group

resource "aws_security_group" "task-1-sg" {
  depends_on = [ aws_key_pair.task-1-key, ]
  name        = "task-1-sg"
  description = "Allow SSH AND HTTP inbound traffic"
  vpc_id      = "vpc-b68c3def"


  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }


  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "task-1-sg"
  }

  
  #launching instance ec2
  
  resource "aws_instance" "task-1-os1" {
   depends_on =  [ aws_key_pair.task-1-key,
              aws_security_group.task-1-sg, ] 
   ami                 = "ami-0447a12f28fddb066"
   instance_type = "t2.micro"
   key_name       =  "task-1-key"
   security_groups = [ "task-1-sg" ]
     connection {
     type     = "ssh"
     user     = "ec2-user"
     private_key = tls_private_key.task-1-pri-key.private_key_pem
     host     = aws_instance.task-1-os1.public_ip
   }
   provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }
  tags = {
      Name =  "task-1-os1"
           }
}
