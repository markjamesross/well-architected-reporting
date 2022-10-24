#Discover details about current AWS session
data "aws_caller_identity" "current" {}
#Data object to create S3 bucket policy
data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    actions = [
      "s3:*",
    ]
    resources = [
      "arn:aws:s3:::${var.service_name}-${data.aws_caller_identity.current.account_id}",
      "arn:aws:s3:::${var.service_name}-${data.aws_caller_identity.current.account_id}/*"
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values = [
        "false"
      ]
    }
  }
}
#Lambda Policy
data "aws_iam_policy_document" "lambda" {
  statement {
    sid = "AllowS3"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]
    effect = "Allow"
    resources = [
      "arn:aws:s3:::${var.service_name}-${data.aws_caller_identity.current.account_id}",
      "arn:aws:s3:::${var.service_name}-${data.aws_caller_identity.current.account_id}/*"
    ]
  }
}