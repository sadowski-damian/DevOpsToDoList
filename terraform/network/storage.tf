resource "aws_s3_bucket" "monitoring_config" {
  bucket = "wenttoprod-monitoring-config"
}

resource "aws_s3_bucket_public_access_block" "monitoring_config" {
  bucket = aws_s3_bucket.monitoring_config.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "monitoring_s3" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.monitoring_config.arn}/grafana/*"]
  }
}

resource "aws_iam_policy" "monitoring_s3" {
  name   = "monitoring-s3-policy"
  policy = data.aws_iam_policy_document.monitoring_s3.json
}