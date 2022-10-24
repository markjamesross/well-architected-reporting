output "s3_bucket" {
    value = aws_s3_bucket.reporting.id
}
output "lambda_role" {
    value = aws_iam_role.reporting.arn
}
