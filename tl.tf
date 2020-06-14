provider "aws" {
  region = "ap-south-1"
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
tags = {
    Name = "allow_http"
  }
}

resource "aws_instance" "myos" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "day3"
  security_groups = [ "allow_http" ]

  connection {
    agent    = "false"
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("/a/day3.pem")
    host     = aws_instance.myos.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd -y", 
      "sudo yum install php -y",
      "sudo yum install git -y",
      "setenforce 0",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "cloud-os"
  }

}

resource "aws_ebs_volume" "ebs1" {
  availability_zone = aws_instance.myos.availability_zone
  size              = 2
  
  tags = {
    Name = "ebs1"
  }
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ebs1.id
  instance_id = aws_instance.myos.id
  force_detach = true
}

resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.ebs_att,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("/a/day3.pem")
    host     = aws_instance.myos.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/1398abhisingh911/CLOUD_TASK_1.git /var/www/html/"
    ]
  }
}

resource "aws_s3_bucket" "b" {
  bucket = "1398abhisingh911"
  acl    = "public-read"

tags = {
    Name = "1398abhisingh911"
  }
}

resource "aws_s3_bucket_object" "s3obj" {
depends_on = [
  aws_s3_bucket.b,
]
  bucket       = "1398abhisingh911"
  key          = "aa.jpg "
  source       = "/a/aa.jpg "
  acl          = "public-read"
  content_type = "image or jpg"
}

locals {
  s3_origin_id = "myS3Origin"
}

output "b" {
  value = aws_s3_bucket.b
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "This is origin access identity"
}

output "origin_access_identity" {
  value = aws_cloudfront_origin_access_identity.origin_access_identity
}


data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.b.arn}/*"]
principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"]
    }
  }
statement {
    actions   = ["s3:ListBucket"]
    resources = ["${aws_s3_bucket.b.arn}"]
principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"]
    }
  }
}

resource "aws_s3_bucket_policy" "example" {
  bucket = aws_s3_bucket.b.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

resource "aws_cloudfront_distribution" "s3_distribution" {
origin {
    domain_name = aws_s3_bucket.b.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }
enabled             = true
  is_ipv6_enabled     = true
default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id
forwarded_values {
      query_string = false
cookies {
        forward = "none"
      }
    }
viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
viewer_certificate {
    cloudfront_default_certificate = true
  }
}
