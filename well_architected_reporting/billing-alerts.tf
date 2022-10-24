#Enables Billing Alerts for this Account 
resource "aws_budgets_budget" "aws_billing_alert" {
  for_each = toset(var.billing_alert_price)
  name     = "${each.key} Billing Alert"

  budget_type  = "COST"
  limit_amount = each.key
  limit_unit   = var.billing_alert_unit
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.subscriber_email_addresses
  }
}