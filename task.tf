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


#Uploading Image to S3
resource "aws_s3_bucket_object" "task-1-object" {
  depends_on = [ aws_s3_bucket.task-1-s3bucket,
                null_resource.null-remote-1,
                null_resource.nulllocal32,
 ]
     bucket = aws_s3_bucket.task-1-s3bucket.id
  key    = "one"
  source = "/Users/gunish/Desktop/terraform/terraform.png"
  etag = "/Users/gunish/Desktop/terraform/terraform.png"
  acl = "public-read"
  content_type = "image/png"
}

locals {
  s3_origin_id = "aws_s3_bucket.task-1-s3bucket.id"
}

#Creating Cloudfront and attaching S3 bucket to it.

resource "aws_cloudfront_origin_access_identity" "o" {
     comment = "hello"
 }

resource "aws_cloudfront_distribution" "task-1-s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.task-1-s3bucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
    s3_origin_config {
           origin_access_identity = aws_cloudfront_origin_access_identity.o.cloudfront_access_identity_path 
     }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = "terraform.png"

  logging_config {
    include_cookies = false
    bucket          =  aws_s3_bucket.task-1-s3bucket.bucket_domain_name
    
  }



  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
   

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "IN","CA", "GB", "DE"]
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
output "out3" {
        value = aws_cloudfront_distribution.task-1-s3_distribution.domain_name
}



#Null Resource


resource "null_resource" "null-remote2" {
 depends_on = [ aws_cloudfront_distribution.task-1-s3_distribution, ]
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.task-1-pri-key.private_key_pem
    host     = aws_instance.task-1-os1.public_ip
   }
   provisioner "remote-exec" {
      inline = [
      "sudo su << EOF",
      "echo \"<img src='https://${aws_cloudfront_distribution.task-1-s3_distribution.domain_name}/${aws_s3_bucket_object.task-1-object.key }'>\" >> /var/www/html/index.html",
       "EOF"
   ]
 }
}


#Launching Web-server


resource "null_resource" "nulllocal3" {
  depends_on = [
      null_resource.null-remote2,
   ]
   provisioner "local-exec" {
         command = "start chrome ${aws_instance.task-1-os1.public_ip}/index.php"
    }
}
  
output "myos_ip" {
  value = aws_instance.task-1-os1.public_ip
}
output "private_key" {
  value = tls_private_key.task-1-pri-key.private_key_pem
}
