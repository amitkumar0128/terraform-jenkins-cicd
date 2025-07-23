#!/bin/bash
apt-get update -y
apt-get install -y openjdk-11-jdk git curl

# Docker install (skipped for brevity)

# Jenkins repo
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  > /etc/apt/sources.list.d/jenkins.list

apt-get update -y
apt-get install -y jenkins
systemctl enable jenkins
systemctl start jenkins

# Wait for Jenkins to be ready
sleep 120

# Jenkins CLI & Plugin setup
JENKINS_URL=http://localhost:8080
ADMIN_PASS=$(cat /var/lib/jenkins/secrets/initialAdminPassword)
wget $JENKINS_URL/jnlpJars/jenkins-cli.jar -O /tmp/jenkins-cli.jar

# Create job
cat <<EOF > /tmp/job.xml
<flow-definition plugin="workflow-job">
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition">
    <scm class="hudson.plugins.git.GitSCM">
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>${github_repo_url}</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/main</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
    </scm>
    <scriptPath>Jenkinsfile</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers/>
</flow-definition>
EOF

java -jar /tmp/jenkins-cli.jar -s $JENKINS_URL -auth admin:$ADMIN_PASS create-job my-pipeline < /tmp/job.xml
