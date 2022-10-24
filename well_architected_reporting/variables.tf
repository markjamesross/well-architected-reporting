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
#Variables for billing alerts
variable "billing_alert_price" {
  type        = list(any)
  description = "The limit alert for billing alerts"
}
variable "billing_alert_unit" {
  type        = string
  description = "The unit of measurement for the budget forecast"
  default     = "USD"
}
variable "subscriber_email_addresses" {
  type        = list(any)
  description = "The email addresses to notify"
}
variable "quicksight_user" {
  type        = string
  description = "Role ARN of Quicksight users"
}