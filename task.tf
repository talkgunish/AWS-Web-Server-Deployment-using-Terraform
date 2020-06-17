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

  
#ebs volume create and attach
  
  resource "aws_ebs_volume" "task-1-ebs" {
  depends_on = [
    aws_instance.task-1-os1,
  ]
  availability_zone = aws_instance.task-1-os1.availability_zone
  size              = 1
  tags = {
    Name = "task-1-ebs"
  }
}


resource "aws_volume_attachment" "ebs_att" {
   depends_on = [ aws_ebs_volume.task-1-ebs, ]
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.task-1-ebs.id
  instance_id = aws_instance.task-1-os1.id
  force_detach = true
}

  
  #config and mount ebs
  
  
  resource "null_resource" "null-remote-1"  {
  depends_on = [
      aws_volume_attachment.ebs_att,
  ]
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.task-1-pri-key.private_key_pem
    host     = aws_instance.task-1-os1.public_ip
  }
  provisioner "remote-exec" {
      inline = [
        "sudo mkfs.ext4  /dev/xvdh",
        "sudo mount  /dev/xvdh  /var/www/html" ,
        "sudo rm -rf /var/www/html/*",                                
       "sudo git clone https://github.com/talkgunish/Infrastructure-Deployment-using-Terraform.git  /var/www/html/",
      ]
  }
    }   
    
    #Download github repo to local-system
    
    resource "null_resource" "nulllocal32"  {
depends_on = [
    null_resource.null-remote-1,    
  ]   
 provisioner "local-exec" {
    command = "https://github.com/talkgunish/Infrastructure-Deployment-using-Terraform.git  /Users/gunish/Desktop/terraform/repo/"
    when    = destroy
   }
      }
    
    
#Creating S3 bucket.

resource "aws_s3_bucket" "task-1-s3bucket" {
depends_on = [
    null_resource.nulllocal32,    
  ]     
  bucket = "task-1-s3bucket"
  force_destroy = true
  acl    = "public-read"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "MYBUCKETPOLICY",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": "arn:aws:s3:::task-1-s3bucket/*"
    }
  ]
}
POLICY
}

