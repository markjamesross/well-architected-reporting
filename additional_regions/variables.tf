variable "region" {
  type        = string
  description = "Region to deploy to"
}
variable "deployment_tool" {
  type        = string
  description = "Tool used to configure service"
  default     = "terraform"
}
variable "env_name" {
  type        = string
  description = "Name of the envrionment"
}
variable "team" {
  type        = string
  description = "Team managing the service"
}
variable "repository_name" {
  type        = string
  description = "Repo name"
  default     = "well-architected-reporting"
}
variable "service_name" {
  type        = string
  description = "Name of the service being deployed"
  default     = "well-architected-reporting"
}