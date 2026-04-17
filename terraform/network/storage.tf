# encryption configured
#tfsec:ignore:aws-s3-enable-bucket-encryption
resource "aws_s3_bucket" "monitoring_config" {
  bucket        = "wenttoprod-monitoring-config"
}

# AES256 is enough
#tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "s3_encryption" {
  bucket = aws_s3_bucket.monitoring_config.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "monitoring_config" {
  bucket = aws_s3_bucket.monitoring_config.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "logs_bucket_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.monitoring_config.arn}/alb-logs/*"]
  }

  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.monitoring_config.arn]
  }

  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.monitoring_config.arn}/cloudtrail/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "logs_bucket_policy" {
  bucket = aws_s3_bucket.monitoring_config.id
  policy = data.aws_iam_policy_document.logs_bucket_policy.json
}

data "aws_iam_policy_document" "monitoring_s3" {
  statement {
    effect  = "Allow"
    actions = ["s3:GetObject"]
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["${aws_s3_bucket.monitoring_config.arn}/grafana/*"]
  }
}

resource "aws_iam_policy" "monitoring_s3" {
  name   = "monitoring-s3-policy"
  policy = data.aws_iam_policy_document.monitoring_s3.json
}