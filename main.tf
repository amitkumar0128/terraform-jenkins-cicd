# Security Group
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Allow SSH and Jenkins ports"
  vpc_id      = data.aws_vpc.default.id

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



# Key Pair for SSH
resource "tls_private_key" "jenkins_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "jenkins_key" {
  key_name   = "jenkins-key"
  public_key = tls_private_key.jenkins_key.public_key_openssh
}

# EC2 Instance
resource "aws_instance" "jenkins" {
  ami                    = "ami-0f918f7e67a3323f0"
  instance_type          = var.instance_type
  key_name               = aws_key_pair.jenkins_key.key_name

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update & install dependencies
    apt-get update -y
    apt-get upgrade -y
    apt-get install -y openjdk-11-jdk git curl

    # Install Docker
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io
    usermod -aG docker ubuntu

    sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
    echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
    https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
    /etc/apt/sources.list.d/jenkins.list > /dev/null
    
    sudo apt-get update
    sudo apt-get install jenkins

    # Start Jenkins
    systemctl enable jenkins
    systemctl start jenkins

    # Wait for Jenkins to start
    sleep 60

    # Install Jenkins plugins via CLI
    JENKINS_CLI=/tmp/jenkins-cli.jar
    JENKINS_URL=http://localhost:8080
    ADMIN_PASS=$(cat /var/lib/jenkins/secrets/initialAdminPassword)
    wget $JENKINS_URL/jnlpJars/jenkins-cli.jar -O $JENKINS_CLI

    # Install plugins
    for plugin in ${join(" ", var.jenkins_plugins)}; do
      java -jar $JENKINS_CLI -s $JENKINS_URL -auth admin:$ADMIN_PASS install-plugin $plugin
    done

    # Restart Jenkins to activate plugins
    java -jar $JENKINS_CLI -s $JENKINS_URL -auth admin:$ADMIN_PASS safe-restart

    # Clone GitHub repo
    mkdir -p /var/lib/jenkins/jobs
    git clone "${var.github_repo_url}" /var/lib/jenkins/jobs/clonedrepo

    # Seed Jenkins pipeline job using CLI
    JOB_CONFIG=/tmp/jenkins-job.xml
    cat <<EOL > $JOB_CONFIG
    <flow-definition plugin="workflow-job">
      <description>Automated pipeline from ${var.github_repo_url}</description>
      <keepDependencies>false</keepDependencies>
      <properties/>
      <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps">
        <scm class="hudson.plugins.git.GitSCM" plugin="git">
          <configVersion>2</configVersion>
          <userRemoteConfigs>
            <hudson.plugins.git.UserRemoteConfig>
              <url>${var.github_repo_url}</url>
            </hudson.plugins.git.UserRemoteConfig>
          </userRemoteConfigs>
          <branches>
            <hudson.plugins.git.BranchSpec>
              <name>*/main</name>
            </hudson.plugins.git.BranchSpec>
          </branches>
          <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
          <submoduleCfg class="list"/>
          <extensions/>
        </scm>
        <scriptPath>Jenkinsfile</scriptPath>
        <lightweight>true</lightweight>
      </definition>
      <triggers/>
      <disabled>false</disabled>
    </flow-definition>
    EOL

    java -jar $JENKINS_CLI -s $JENKINS_URL -auth admin:$ADMIN_PASS create-job my-pipeline < $JOB_CONFIG
  EOF

  tags = {
    Name    = "Jenkins-EC2"
    Project = "Terraform Jenkins Pipeline"
  }

  # For SSH access via output
  provisioner "local-exec" {
    command = "echo '${tls_private_key.jenkins_key.private_key_pem}' > ./jenkins_key.pem && chmod 600 ./jenkins_key.pem"
  }
}

# Output Jenkins URL
output "jenkins_url" {
  description = "Jenkins is running at http://<ip>:8080"
  value       = "Jenkins is running at http://${aws_instance.jenkins.public_ip}:8080"
}