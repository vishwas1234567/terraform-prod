# Configure the AWS provider
provider "aws" {
  region = "us-east-1" # Update to your desired AWS region
}

# Configure the S3 backend
terraform {
  backend "s3" {
    bucket = "new-state-bucket" # Update with your S3 bucket name
    key    = "state/terraform.tfstate" # Update with the desired path and filename
    region = "us-east-1" # Update to your desired AWS region
  }
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "GenericVPC"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "GenericInternetGateway"
  }
}

# Create a Subnet
resource "aws_subnet" "main" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "GenericSubnet"
  }
}

# Create a Route Table
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "GenericRouteTable"
  }
}

# Associate the Route Table with the Subnet
resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

# Create a Security Group
resource "aws_security_group" "main" {
  vpc_id = aws_vpc.main.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "GenericSecurityGroup"
  }
}

# Create an EC2 Instance
resource "aws_instance" "main" {
  ami                    = "ami-0cd60fd97301e4b49" # Update to a valid AMI for your region
  instance_type          = "t2.micro" # Free Tier eligible
  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.main.id]
  associate_public_ip_address = true

  key_name = "new12" # Update with your AWS key pair name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "Welcome to your generic EC2 instance!" > /var/www/html/index.html
              EOF

  tags = {
    Name = "GenericEC2Instance"
  }
}

# Output the public IP of the EC2 instance
output "ec2_public_ip" {
  value = aws_instance.main.public_ip
}

# Create an RDS Instance
resource "aws_db_instance" "main" {
  allocated_storage    = 20
  engine               = "mysql"
  engine_version      = "5.7"
  instance_class       = "db.t2.micro" # Free Tier eligible
  db_name              = "genericdb"
  username             = "admin"
  password             = "YourPassword1"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
  vpc_security_group_ids = [aws_security_group.main.id]
  db_subnet_group_name = aws_db_subnet_group.main.name

  tags = {
    Name = "GenericRDSInstance"
  }
}

# Create a DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "main"
  subnet_ids = [aws_subnet.main.id]

  tags = {
    Name = "GenericDBSubnetGroup"
  }
}

# Create an S3 Bucket
resource "aws_s3_bucket" "data_bucket" {
  bucket = "generic-data-bucket"

  tags = {
    Name = "GenericDataBucket"
  }
}

# Create an S3 Bucket ACL
resource "aws_s3_bucket_acl" "data_bucket_acl" {
  bucket = aws_s3_bucket.data_bucket.id
  acl    = "private"

  depends_on = [aws_s3_bucket.data_bucket]
}

# Create an IAM Role for EC2 to access S3
resource "aws_iam_role" "ec2_s3_access_role" {
  name = "ec2_s3_access_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "EC2S3AccessRole"
  }
}

# Create an IAM Policy for S3 Access
resource "aws_iam_policy" "s3_access_policy" {
  name        = "s3_access_policy"
  description = "Policy for S3 access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::generic-data-bucket",
          "arn:aws:s3:::generic-data-bucket/*"
        ]
      },
    ]
  })
}

# Attach the IAM Policy to the IAM Role
resource "aws_iam_role_policy_attachment" "s3_access_attachment" {
  role       = aws_iam_role.ec2_s3_access_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

# Create a Redshift Cluster
resource "aws_redshift_cluster" "main" {
  cluster_identifier   = "generic-redshift-cluster"
  database_name        = "genericdb"
  master_username      = "admin"
  master_password      = "YourPassword1"
  node_type            = "dc2.large" # Free Tier eligible for 2 months
  cluster_type         = "single-node"
  vpc_security_group_ids = [aws_security_group.main.id]

  tags = {
    Name = "GenericRedshiftCluster"
  }
}

# Create a Glue Data Catalog
resource "aws_glue_catalog_database" "main" {
  name = "generic_glue_database"
}

# Create an EMR Cluster
resource "aws_emr_cluster" "main" {
  name          = "generic-emr-cluster"
  release_label = "emr-5.33.0"
  applications  = ["Spark"]

  ec2_attributes {
    subnet_id                         = aws_subnet.main.id
    emr_managed_master_security_group = aws_security_group.main.id
    emr_managed_slave_security_group  = aws_security_group.main.id
    instance_profile                  = aws_iam_instance_profile.emr_profile.id
  }

  master_instance_group {
    instance_type = "m5.large" # Free Tier eligible for 50 hours per month
  }

  core_instance_group {
    instance_type  = "m5.large" # Free Tier eligible for 50 hours per month
    instance_count = 2
  }

  service_role = aws_iam_role.emr_service_role.arn

  tags = {
    Name = "GenericEMRCluster"
  }
}

# Create an IAM Instance Profile for EMR
resource "aws_iam_instance_profile" "emr_profile" {
  name = "emr_profile"
  role = aws_iam_role.emr_role.name
}

# Create an IAM Role for EMR
resource "aws_iam_role" "emr_role" {
  name = "emr_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "elasticmapreduce.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "EMRRole"
  }
}

# Create an IAM Policy for EMR
resource "aws_iam_policy" "emr_policy" {
  name        = "emr_policy"
  description = "Policy for EMR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:CreateSecurityGroup",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:ModifyImageAttribute",
          "ec2:ModifyInstanceAttribute",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "elasticmapreduce:AddJobFlowSteps",
          "elasticmapreduce:DescribeCluster",
          "elasticmapreduce:ModifyInstanceGroups",
          "elasticmapreduce:TerminateJobFlows",
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

# Attach the IAM Policy to the IAM Role
resource "aws_iam_role_policy_attachment" "emr_policy_attachment" {
  role       = aws_iam_role.emr_role.name
  policy_arn = aws_iam_policy.emr_policy.arn
}

# Create an IAM Role for EMR Service
resource "aws_iam_role" "emr_service_role" {
  name = "emr_service_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "elasticmapreduce.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "EMRServiceRole"
  }
}

# Create an IAM Policy for EMR Service
resource "aws_iam_policy" "emr_service_policy" {
  name        = "emr_service_policy"
  description = "Policy for EMR Service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:CreateSecurityGroup",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:ModifyImageAttribute",
          "ec2:ModifyInstanceAttribute",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "elasticmapreduce:AddJobFlowSteps",
          "elasticmapreduce:DescribeCluster",
          "elasticmapreduce:ModifyInstanceGroups",
          "elasticmapreduce:TerminateJobFlows",
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

# Attach the IAM Policy to the IAM Role for EMR Service
resource "aws_iam_role_policy_attachment" "emr_service_policy_attachment" {
  role       = aws_iam_role.emr_service_role.name
  policy_arn = aws_iam_policy.emr_service_policy.arn
}
