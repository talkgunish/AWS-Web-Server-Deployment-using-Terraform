provider "aws" {
  region  = "ap-south-1"
  profile = "mrtiwari"
}



resource "tls_private_key" "task-1-pri-key" { 
  algorithm   = "RSA"
  rsa_bits = 2048
}


resource "aws_key_pair" "task-1-key" {
  depends_on = [ tls_private_key.task-1-pri-key, ]
  key_name   = "task-1-key"
  public_key = tls_private_key.task-1-pri-key.public_key_openssh
}
