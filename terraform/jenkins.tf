data "aws_ami" "ubuntu_jenkins" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name = "name"
    values = [
      "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
    ]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}


resource "aws_key_pair" "jenkins" {
  key_name = "${var.project_name}-${var.environment}-jenkins-key"

  public_key = file(
    pathexpand(var.jenkins_public_key_path)
  )

  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins-key"
  }
}


resource "aws_security_group" "jenkins" {
  name        = "${var.project_name}-${var.environment}-jenkins-sg"
  description = "Security group for Jenkins server"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from administrator"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"

    cidr_blocks = [
      var.jenkins_admin_cidr
    ]
  }

  ingress {
    description = "Jenkins Web UI from administrator"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"

    cidr_blocks = [
      var.jenkins_admin_cidr
    ]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins-sg"
  }
}


resource "aws_iam_role" "jenkins" {
  name = "${var.project_name}-${var.environment}-jenkins-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins-role"
  }
}


resource "aws_iam_role_policy_attachment" "jenkins_ecr" {
  role = aws_iam_role.jenkins.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}


resource "aws_iam_role_policy_attachment" "jenkins_ssm" {
  role = aws_iam_role.jenkins.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


resource "aws_iam_role_policy" "jenkins_eks_describe" {
  name = "${var.project_name}-${var.environment}-jenkins-eks"

  role = aws_iam_role.jenkins.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]

        Resource = "*"
      }
    ]
  })
}


resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.project_name}-${var.environment}-jenkins-profile"
  role = aws_iam_role.jenkins.name
}


resource "aws_eks_access_entry" "jenkins" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.jenkins.arn
  type          = "STANDARD"

  depends_on = [
    aws_eks_cluster.main
  ]
}


resource "aws_eks_access_policy_association" "jenkins" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.jenkins.arn

  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"

  access_scope {
    type = "namespace"

    namespaces = [
      "devops-app"
    ]
  }

  depends_on = [
    aws_eks_access_entry.jenkins
  ]
}


resource "aws_instance" "jenkins" {
  ami           = data.aws_ami.ubuntu_jenkins.id
  instance_type = var.jenkins_instance_type

  subnet_id = aws_subnet.public_1.id

  associate_public_ip_address = true

  key_name = aws_key_pair.jenkins.key_name

  vpc_security_group_ids = [
    aws_security_group.jenkins.id
  ]

  iam_instance_profile = aws_iam_instance_profile.jenkins.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins"
    Role = "jenkins"
  }

  depends_on = [
    aws_iam_role_policy_attachment.jenkins_ecr,
    aws_iam_role_policy_attachment.jenkins_ssm
  ]
}

resource "aws_vpc_security_group_ingress_rule" "eks_api_from_jenkins" {
  security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id

  referenced_security_group_id = aws_security_group.jenkins.id

  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443

  description = "Allow Jenkins server to access EKS private API endpoint"
}
