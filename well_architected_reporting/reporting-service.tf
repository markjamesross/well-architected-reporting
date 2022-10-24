#Reporting solution - https://aws.amazon.com/blogs/mt/use-amazon-athena-and-amazon-quicksight-to-build-custom-reports-of-aws-well-architected-reviews/
#Account wide S3 settings to avoid making data publicly accessible 
resource "aws_s3_account_public_access_block" "s3_public_access_block" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
#Create bucket for reporting
resource "aws_s3_bucket" "reporting" {
  bucket = "${var.service_name}-${data.aws_caller_identity.current.account_id}"
  tags = {
    Name = var.service_name
  }
}
#Attache bucket policy
resource "aws_s3_bucket_policy" "reporting" {
  bucket = aws_s3_bucket.reporting.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}
#Apply versioning
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.reporting.id
  versioning_configuration {
    status = "Enabled"
  }
}
#Apply ACL
resource "aws_s3_bucket_acl" "this" {
  bucket = aws_s3_bucket.reporting.id
  acl    = "private"
}
#Apply SSE
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.reporting.id
  rule {
    bucket_key_enabled = true
    apply_server_side_encryption_by_default {
      #Use S3 key
      sse_algorithm = "aws:kms"
    }
  }
}
#Apply security public blocking settings
resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.reporting.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
#Lambda Function for Reporting
resource "aws_lambda_function" "reporting" {
  filename         = "./source/extract-war-reports.zip"
  source_code_hash = filebase64sha256("./source/extract-war-reports.zip")
  function_name    = "extract-war-reports"
  role             = aws_iam_role.reporting.arn
  handler          = "extract-war-reports.lambda_handler"
  runtime          = "python3.6"
  memory_size      = 256
  timeout          = 180

  environment {
    variables = {
      LOG_LEVEL = "10"
      S3_BUCKET = aws_s3_bucket.reporting.id
      S3_KEY    = "WorkloadReports/"
    }
  }
}
#Lambda Role
resource "aws_iam_role" "reporting" {
  name = "extract-war-reports_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": "LambdaAssumeRole"
    }
  ]
}
EOF
}
#Attach basic execution role to Lambda
resource "aws_iam_role_policy_attachment" "basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.reporting.name
}
#Attach WAF read only to Lambda
resource "aws_iam_role_policy_attachment" "waf" {
  policy_arn = "arn:aws:iam::aws:policy/WellArchitectedConsoleReadOnlyAccess"
  role       = aws_iam_role.reporting.name
}
#Create Policy to allow S3 access
resource "aws_iam_policy" "waf_s3_access" {
  name        = "waf_s3_access_policy"
  path        = "/"
  description = "Access to WAF S3 bucket"

  policy = data.aws_iam_policy_document.lambda.json
}
#Attach S3 Access Policy to Lambda
resource "aws_iam_role_policy_attachment" "waf_s3" {
  policy_arn = aws_iam_policy.waf_s3_access.arn
  role       = aws_iam_role.reporting.name
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
#Glue database
resource "aws_glue_catalog_database" "reporting" {
  name = "war-reports"
}
#Glue Crawler
resource "aws_glue_crawler" "reporting" {
  database_name = aws_glue_catalog_database.reporting.name
  name          = "well-architected-reporting"
  role          = aws_iam_role.glue.arn
  schedule      = "cron(0 8 1 * ? *)"
  s3_target {
    path = "s3://${aws_s3_bucket.reporting.bucket}/WorkloadReports"
  }
}
#glue Role
resource "aws_iam_role" "glue" {
  name = "well-architected-reporting"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "glue.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": "GlueAssumeRole"
    }
  ]
}
EOF
}
#Attach WAF read only to Glue
resource "aws_iam_role_policy_attachment" "glue" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
  role       = aws_iam_role.glue.name
}
#Attach S3 Access Policy to Glue
resource "aws_iam_role_policy_attachment" "glue_s3" {
  policy_arn = aws_iam_policy.waf_s3_access.arn
  role       = aws_iam_role.glue.name
}
#Cloudwatch logs for Glue
resource "aws_cloudwatch_log_group" "glue" {
  name              = "/aws-glue/crawlers"
  retention_in_days = 14
}
#Athena Workgroup set-up
resource "aws_athena_workgroup" "waf" {
  name = "well-architected-framework-workgroup"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.reporting.bucket}/athena/output/"
    }
  }
}
#Athena Query for report answers
resource "aws_athena_named_query" "report_answers" {
  name      = "well_architected_reports_view"
  workgroup = aws_athena_workgroup.waf.id
  database  = aws_glue_catalog_database.reporting.id
  query     = <<EOF
CREATE OR REPLACE VIEW well_architected_reports_view AS
SELECT workload_id,
         workload_name,
         workload_owner,
CAST(from_iso8601_timestamp(workload_lastupdated) AS timestamp) AS "timestamp",
         answers.QuestionTitle,
         answers.LensAlias,
         answers.pillarid,
         answers.risk
FROM "workloadreports"
CROSS JOIN unnest(report_answers) AS t(answers)
EOF
}
#Athena Query for lenses
resource "aws_athena_named_query" "lens" {
  name      = "well_architected_workload_lens_risk_view"
  workgroup = aws_athena_workgroup.waf.id
  database  = aws_glue_catalog_database.reporting.id
  query     = <<EOF
CREATE
        OR REPLACE VIEW well_architected_workload_lens_risk_view AS
SELECT workload_id,
         workload_name,
         lens.LensAlias,
         lens_pillar_summary.PillarId,
         lens_pillar_summary.RiskCounts.UNANSWERED,
         lens_pillar_summary.RiskCounts.HIGH,
         lens_pillar_summary.RiskCounts.MEDIUM,
         lens_pillar_summary.RiskCounts.NONE,
         lens_pillar_summary.RiskCounts.NOT_APPLICABLE
FROM "workloadreports"
CROSS JOIN unnest(lens_summary) AS t(lens)
CROSS JOIN unnest(lens.PillarReviewSummaries) AS tt(lens_pillar_summary) 
EOF
}
#Athena Query for milestones
resource "aws_athena_named_query" "milestones" {
  name      = "well_architected_workload_milestone_view"
  workgroup = aws_athena_workgroup.waf.id
  database  = aws_glue_catalog_database.reporting.id
  query     = <<EOF
CREATE
        OR REPLACE VIEW well_architected_workload_milestone_view AS
SELECT CAST(from_iso8601_timestamp(milestone.RecordedAt) AS timestamp) AS "timestamp",
         workload_id,
         workload_name,
         workload_owner,
         milestone.MilestoneName,
         milestone.MilestoneNumber,
         milestone.WorkloadSummary.ImprovementStatus,
         milestone.WorkloadSummary.RiskCounts.HIGH,
         milestone.WorkloadSummary.RiskCounts.MEDIUM,
         milestone.WorkloadSummary.RiskCounts.UNANSWERED,
         milestone.WorkloadSummary.RiskCounts.NONE,
         milestone.WorkloadSummary.RiskCounts.NOT_APPLICABLE
FROM "workloadreports"
CROSS JOIN unnest(milestones) AS t(milestone) 
EOF
}
#Quicksight data source
resource "aws_quicksight_data_source" "reporting" {
  data_source_id = "well-architected-datasource"
  name           = "Well Architected Datasource"
  ssl_properties {
    disable_ssl = false
  }
  parameters {
    athena {
      work_group = aws_athena_workgroup.waf.id
    }
  }
  type = "ATHENA"
  permission {
    actions = ["quicksight:UpdateDataSourcePermissions", "quicksight:DescribeDataSourcePermissions", "quicksight:PassDataSource", "quicksight:DescribeDataSource", "quicksight:DeleteDataSource", "quicksight:UpdateDataSource"]
    principal = var.quicksight_user
  }
}
#Quicksight data sets using AWS Cloud Control Terraform Resources as standard Terraform provider doesn't support these resources
resource "awscc_quicksight_data_set" "reports_view" {
  aws_account_id = data.aws_caller_identity.current.account_id
  name = "well-architected-reports-view"
  data_set_id = "well-architected-reports-view"
  import_mode = "DIRECT_QUERY"
  permissions = [
    {
      actions = [
        "quicksight:PassDataSet",
        "quicksight:DescribeIngestion",
        "quicksight:CreateIngestion",
        "quicksight:UpdateDataSet",
        "quicksight:DeleteDataSet",
        "quicksight:DescribeDataSet",
        "quicksight:CancelIngestion",
        "quicksight:DescribeDataSetPermissions",
        "quicksight:ListIngestions",
        "quicksight:UpdateDataSetPermissions"
      ]
      principal = var.quicksight_user
    }
  ]
  logical_table_map = {
    table = {
      alias  = aws_athena_named_query.report_answers.name
      source = {
        physical_table_id = "table"
      }
    }
  }
  physical_table_map = {
    table = {
      relational_table = {
        catalog = "AwsDataCatalog"
        data_source_arn = aws_quicksight_data_source.reporting.arn
        schema = aws_glue_catalog_database.reporting.name
        name = aws_athena_named_query.report_answers.name
        input_columns = [
          {
              name =  "workload_id"
              type = "STRING"
          },
          {
              name = "workload_name"
              type = "STRING"
          },
          {
              name = "workload_owner"
              type = "STRING"
          },
          {
              name = "timestamp"
              type = "DATETIME"
          },
          {
              name = "questiontitle"
              type = "STRING"
          },
          {
              name = "lensalias"
              type = "STRING"
          },
          {
              name = "pillarid"
              type = "STRING"
          },
          {
              name = "risk"
              type = "STRING"
          }
        ]
      }
    }
  }
}
resource "awscc_quicksight_data_set" "milestone_view" {
  aws_account_id = data.aws_caller_identity.current.account_id
  name = "well-architected-milestone-view"
  data_set_id = "well-architected-milestone-view"
  import_mode = "DIRECT_QUERY"
  permissions = [
    {
      actions = [
        "quicksight:PassDataSet",
        "quicksight:DescribeIngestion",
        "quicksight:CreateIngestion",
        "quicksight:UpdateDataSet",
        "quicksight:DeleteDataSet",
        "quicksight:DescribeDataSet",
        "quicksight:CancelIngestion",
        "quicksight:DescribeDataSetPermissions",
        "quicksight:ListIngestions",
        "quicksight:UpdateDataSetPermissions"
      ]
      principal = var.quicksight_user
    }
  ]
  logical_table_map = {
    table = {
      alias  = aws_athena_named_query.milestones.name
      source = {
        physical_table_id = "table"
      }
    }
  }
  physical_table_map = {
    table = {
      relational_table = {
        catalog = "AwsDataCatalog"
        data_source_arn = aws_quicksight_data_source.reporting.arn
        schema = aws_glue_catalog_database.reporting.name
        name = aws_athena_named_query.milestones.name
        input_columns = [
          {
              name = "timestamp"
              type = "DATETIME"
          },
          {
              name = "workload_id"
              type = "STRING"
          },
          {
              name = "workload_name"
              type = "STRING"
          },
          {
              name = "workload_owner"
              type = "STRING"
          },
          {
              name = "milestonename"
              type = "STRING"
          },
          {
              name = "milestonenumber"
              type = "INTEGER"
          },
          {
              name = "improvementstatus"
              type = "STRING"
          },
          {
              name = "high"
              type = "INTEGER"
          },
          {
              name = "medium"
              type = "INTEGER"
          },
          {
              name = "unanswered"
              type = "INTEGER"
          },
          {
              name = "none"
              type = "INTEGER"
          },
          {
              name = "not_applicable"
              type = "INTEGER"
          }
        ]
      }
    }
  }
}
resource "awscc_quicksight_data_set" "lens_view" {
  aws_account_id = data.aws_caller_identity.current.account_id
  name = "well-architected-lens-view"
  data_set_id = "well-architected-lens-view"
  import_mode = "DIRECT_QUERY"
  permissions = [
    {
      actions = [
        "quicksight:PassDataSet",
        "quicksight:DescribeIngestion",
        "quicksight:CreateIngestion",
        "quicksight:UpdateDataSet",
        "quicksight:DeleteDataSet",
        "quicksight:DescribeDataSet",
        "quicksight:CancelIngestion",
        "quicksight:DescribeDataSetPermissions",
        "quicksight:ListIngestions",
        "quicksight:UpdateDataSetPermissions"
      ]
      principal = var.quicksight_user
    }
  ]
  logical_table_map = {
    table = {
      alias  = aws_athena_named_query.lens.name
      source = {
        physical_table_id = "table"
      }
    }
  }
  physical_table_map = {
    table = {
      relational_table = {
        catalog = "AwsDataCatalog"
        data_source_arn = aws_quicksight_data_source.reporting.arn
        schema = aws_glue_catalog_database.reporting.name
        name = aws_athena_named_query.lens.name
        input_columns = [
          {
              name = "timestamp"
              type = "DATETIME"
          },
          {
              name = "workload_id"
              type = "STRING"
          },
          {
              name = "workload_name"
              type = "STRING"
          },
          {
              name = "workload_owner"
              type = "STRING"
          },
          {
              name = "milestonename"
              type = "STRING"
          },
          {
              name = "milestonenumber"
              type = "INTEGER"
          },
          {
              name = "improvementstatus"
              type = "STRING"
          },
          {
              name = "high"
              type = "INTEGER"
          },
          {
              name = "medium"
              type = "INTEGER"
          },
          {
              name = "unanswered"
              type = "INTEGER"
          },
          {
              name = "none"
              type = "INTEGER"
          },
          {
              name = "not_applicable"
              type = "INTEGER"
          }
        ]
      }
    }
  }
}