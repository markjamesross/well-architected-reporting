#Lambda Function for Reporting
resource "aws_lambda_function" "reporting" {
  filename         = "./source/extract-war-reports.zip"
  source_code_hash = filebase64sha256("../well_architected_reporting/source/extract-war-reports.zip")
  function_name    = "extract-war-reports"
  role             = data.terraform_remote_state.waf.outputs.lambda_role
  handler          = "extract-war-reports.lambda_handler"
  runtime          = "python3.6"
  memory_size      = 256
  timeout          = 180

  environment {
    variables = {
      LOG_LEVEL = "10"
      S3_BUCKET = data.terraform_remote_state.waf.outputs.s3_bucket
      S3_KEY    = "WorkloadReports/"
    }
  }
}
#Event Rule to trigger Lambda daily
resource "aws_cloudwatch_event_rule" "reporting" {
  name                = "LambdaExtractWARReportsSchedule"
  description         = "Well Architected Framework Reporting"
  schedule_expression = "rate(1 day)"
}
#Event Target
resource "aws_cloudwatch_event_target" "reporting" {
  rule = aws_cloudwatch_event_rule.reporting.name
  arn  = aws_lambda_function.reporting.arn
}
#Cloudwatch invoke permissions
resource "aws_lambda_permission" "reporting" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.reporting.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.reporting.arn
}
#Cloudwatch logs for Lambda
resource "aws_cloudwatch_log_group" "reporting" {
  name              = "/aws/lambda/extract-war-reports"
  retention_in_days = 14
}