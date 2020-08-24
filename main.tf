resource "tls_private_key" "my-task2key" {
algorithm = "RSA"
}
resource "aws_key_pair" "my-key" {
key_name = "my-task2key"
public_key = tls_private_key.my-task2key.public_key_openssh
depends_on = [ tls_private_key.my-task2key,]
}

###### Security group creation ###### 
resource "aws_security_group"  "MYSG"  {
vpc_id      =  "vpc-55b9a43d"  
name = "MYSG"
description = "allow ssh and http traffic"
ingress {
    cidr_blocks = ["0.0.0.0/0"]
  from_port   = 80
 to_port     = 80
 protocol    = "tcp"
  }
ingress {
  cidr_blocks = ["0.0.0.0/0"]
  from_port   = 22
 to_port     = 22
  protocol    = "tcp"
  }
egress {
  from_port   = 0
    to_port     = 0
   protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  
}
}

######### Create instance ##########
resource "aws_instance"  "my-instance"  {
    ami   =  "ami-0732b62d310b80e97"
    instance_type  =  "t2.micro"
    key_name  =  aws_key_pair.my-key.key_name
    security_groups  =  [ "MYSG" ]
   
    
   
    connection  {
              agent   =  "false"
              type     =  "ssh"
              user     =  "ec2-user"
              private_key  =  tls_private_key.my-task2key.private_key_pem
              host     =  aws_instance.my-instance.public_ip
          }
    provisioner  "remote-exec" {
             inline  =  [
                   "sudo  yum install httpd  php  git  -y",
                   "sudo  systemctl  restart  httpd",
                   "sudo systemctl  enable httpd",
               ]
         }
 
   tags  =  {
        Name = "my-instance"
     }
}


######## Create the EFS ##########

resource "aws_efs_file_system" "my-efs" {
   creation_token = "my-efs"
   performance_mode = "generalPurpose"
 tags = {
     Name = "my-efs"
   }
 }
########### Mounting EFS ############

resource "aws_efs_mount_target" "my_efs_mount" {
   file_system_id  = aws_efs_file_system.my-efs.id
   subnet_id = aws_instance.my-instance.subnet_id
   security_groups = ["${aws_security_group.MYSG.id}"]
 }

##################

resource  "null_resource"  "mounting" {
      depends_on = [
            aws_efs_mount_target.my_efs_mount,
      ]
      connection {
             type  =  "ssh"
             user  =  "ec2-user"
             private_key  =  tls_private_key.my-task2key.private_key_pem
             host  =  aws_instance.my-instance.public_ip
       }
      provisioner  "remote-exec" {
             inline  =  [
                 "sudo echo ${aws_efs_file_system.my-efs.dns_name}:/var/www/html  efs  defaults, _netdev 0 0 >> sudo  /etc/fstab",
                 "sudo mount ${aws_efs_file_system.my-efs.dns_name}:/ /var/www/html",
                 "sudo git clone  https://github.com/Yashsharma99/task.git    /var/www/html"
             ]
         }
    
}

resource "aws_s3_bucket"  "my_task2_bucket" {
            bucket  =  "my-tk2-bucket"
            acl  =  "private"
            region = "ap-south-1"
        versioning {
                       enabled  =  true
        }
       tags  =  {
           Name  =  "my-tk2-bucket"
        }
}

resource "aws_s3_bucket_object"  "mytask2bucket_object"  {
         depends_on = [aws_s3_bucket.my_task2_bucket , ]
          bucket  =  aws_s3_bucket.my_task2_bucket.id
          key   =  "myimg.jpg"
          source  =  "C:/myimg.jpg"
          acl  =  "public-read"
   
}



resource "aws_cloudfront_distribution" "my_task2_cloudfront" {
	//depends_on = [aws_s3_bucket.my_task2_bucket , null_resource.local-1 ]
	origin {
		domain_name = aws_s3_bucket.my_task2_bucket.bucket_regional_domain_name
		origin_id   = "S3-my-tk2-bucket"




		custom_origin_config {
			http_port = 80
			https_port = 80
			origin_protocol_policy = "match-viewer"
			origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
		}
	}
 
	enabled = true
  
	default_cache_behavior {
		allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
		cached_methods = ["GET", "HEAD"]
		target_origin_id = "S3-my-tk2-bucket"
 
		forwarded_values {
			query_string = false
 
			cookies {
				forward = "none"
			}
		}
		viewer_protocol_policy = "allow-all"

		min_ttl = 0
		default_ttl = 3600
		max_ttl = 86400
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




output "domain-name" {
	value = aws_cloudfront_distribution.my_task2_cloudfront.domain_name




}