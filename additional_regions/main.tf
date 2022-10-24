provider "aws" {
  region = var.region

  default_tags {
    tags = {
      SourceCode     = element(split("/${var.repository_name}/", path.cwd), 1)
      DeploymentTool = var.deployment_tool
      Environment    = var.env_name
      Service        = var.service_name
      Team           = var.team
    }
  }
}
