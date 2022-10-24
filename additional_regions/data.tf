#Discover details about current AWS session
data "aws_caller_identity" "current" {}
data "terraform_remote_state" "waf" {
  backend = "local"

  config = {
    path = "../well_architected_reporting/terraform.tfstate"
  }
}
