# Security Group
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Allow SSH and Jenkins ports"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "BugTracker App"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins-sg"
    Project = "Terraform Jenkins Pipeline"
  }
}


# EC2 Instance
resource "aws_instance" "jenkins" {
  ami                    = "ami-0f918f7e67a3323f0"
  instance_type          = var.instance_type
  key_name               = aws_key_pair.jenkins_key.key_name
  security_groups = [aws_security_group.jenkins_sg.name]

  user_data = templatefile("${path.module}/jenkins-install.sh.tpl", {
              github_repo_url = var.github_repo_url
            })

  tags = {
    Name    = "Jenkins-EC2"
    Project = "Terraform Jenkins Pipeline"
  }


}

# Output Jenkins URL
output "jenkins_url" {
  description = "Jenkins is running at http://<ip>:8080"
  value       = "Jenkins is running at http://${aws_instance.jenkins.public_ip}:8080"
}