terraform {
  backend "s3" {
    bucket = "new-state-bucket" # Ensure this bucket exists and is accessible
    key    = "state/terraform.tfstate"
    region = "us-east-1" # Ensure this matches the region you intend to use
  }
}

provider "aws" {
  region = "us-east-1" # Ensure this matches the region in your backend configuration
}

provider "aws" {
  alias  = "us-west-2"
  region = "us-west-2"
}

data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Configuration
resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.100.0.0/16"
  tags = {
    Name = "eks-vpc"
  }
}

# Subnets
resource "aws_subnet" "private" {
  count             = 2
  cidr_block        = cidrsubnet(aws_vpc.eks_vpc.cidr_block, 8, count.index)
  vpc_id            = aws_vpc.eks_vpc.id
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "private-subnet-${count.index}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  cidr_block              = cidrsubnet(aws_vpc.eks_vpc.cidr_block, 8, count.index + 2)
  vpc_id                  = aws_vpc.eks_vpc.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-${count.index}"
    "kubernetes.io/role/elb" = "1"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = {
    Name = "eks-igw"
  }
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.eks_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway
resource "aws_eip" "nat" {
  count = 2
}

resource "aws_nat_gateway" "nat" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags = {
    Name = "nat-gw-${count.index}"
  }
}

resource "aws_route_table" "private" {
  count = 2
  vpc_id = aws_vpc.eks_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }
  tags = {
    Name = "private-route-table-${count.index}"
  }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# EKS Cluster
resource "aws_eks_cluster" "cluster" {
  name     = "my-unique-eks-cluster" # Updated to a unique name
  role_arn = aws_iam_role.eks_cluster.arn
  vpc_config {
    subnet_ids = concat(aws_subnet.private[*].id, aws_subnet.public[*].id)
  }
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
  ]
}

resource "aws_iam_role" "eks_cluster" {
  name = "eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# RDS Parameter Group
resource "aws_db_parameter_group" "postgres" {
  name        = "postgres15-parameter-group"
  family      = "postgres15" # Updated to match the PostgreSQL version
  description = "PostgreSQL 15 parameter group"
}

# RDS Instance
resource "aws_db_instance" "default" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "postgres"
  engine_version       = "15.13" # Updated to a valid version
  instance_class       = "db.t3.micro"
  db_name              = "mydb"
  username             = "username"
  password             = "password"
  parameter_group_name = aws_db_parameter_group.postgres.name
  skip_final_snapshot  = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name = aws_db_subnet_group.main.name
}

resource "aws_db_subnet_group" "main" {
  name       = "main"
  subnet_ids = aws_subnet.private[*].id
  tags = {
    Name = "My DB subnet group"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "rds_sg"
  description = "Allow inbound traffic to RDS"
  vpc_id      = aws_vpc.eks_vpc.id
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.100.0.0/16"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Athena Workgroup
resource "aws_athena_workgroup" "example" {
  name = "example"
  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/output/"
    }
  }
}

resource "aws_s3_bucket" "athena_results" {
  provider = aws.us-west-2
  bucket   = "my-unique-athena-results-bucket-20250623" # Updated to a unique name with a date suffix
}

# Additional S3 Bucket
provider "aws" {
  alias  = "ap_northeast_1"
  region = "ap-northeast-1"
}

resource "aws_s3_bucket" "example" {
  provider = aws.ap_northeast_1
  bucket   = "my-unique-example-bucket-20250623" # Updated to a unique name with a date suffix
}

# Lambda Execution Role
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# DynamoDB Table
resource "aws_dynamodb_table" "example" {
  name           = "ExampleTable"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  attribute {
    name = "id"
    type = "S"
  }
}
# AWS Glue Resources

# IAM Role for AWS Glue
resource "aws_iam_role" "glue_role" {
  name = "aws-glue-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy Attachment for AWS Glue
resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# AWS Glue Crawler
resource "aws_glue_crawler" "example" {
  database_name = aws_glue_catalog_database.example.name
  name          = "example-crawler"
  role          = aws_iam_role.glue_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.example.bucket}/"
  }
}

# AWS Glue Database
resource "aws_glue_catalog_database" "example" {
  name = "example_database"
}

# AWS Glue Job
resource "aws_glue_job" "example" {
  name     = "example-glue-job"
  role_arn = aws_iam_role.glue_role.arn

  command {
    script_location = "s3://${aws_s3_bucket.example.bucket}/scripts/example-script.py"
  }
}

# AWS Kinesis Resources

# Kinesis Data Stream
resource "aws_kinesis_stream" "example_stream" {
  name             = "example-stream"
  shard_count      = 1
  retention_period = 24

  shard_level_metrics = [
    "IncomingBytes",
    "OutgoingBytes",
  ]
}

# Kinesis Firehose Delivery Stream
resource "aws_kinesis_firehose_delivery_stream" "example_stream" {
  name        = "example-firehose-stream"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.example.arn
  }
}

# IAM Role for Kinesis Firehose
resource "aws_iam_role" "firehose_role" {
  name = "firehose_delivery_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Kinesis Firehose
resource "aws_iam_role_policy" "firehose_s3_policy" {
  name = "firehose_s3_policy"
  role = aws_iam_role.firehose_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ],
        Effect   = "Allow",
        Resource = [
          aws_s3_bucket.example.arn,
          "${aws_s3_bucket.example.arn}/*"
        ]
      }
    ]
  })
}
