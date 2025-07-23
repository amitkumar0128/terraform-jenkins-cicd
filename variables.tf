# Variables
variable "github_repo_url" {
  description = "Public GitHub repo to clone containing a Jenkinsfile"
  type        = string
  default     = "https://github.com/amitkumar0128/bugtracker.git"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "jenkins_plugins" {
  description = "List of Jenkins plugins to install"
  type        = list(string)
  default     = [
    "docker-plugin",
    "git",
    "workflow-aggregator"
  ]
}
