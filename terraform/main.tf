variable "aws_region" {
  default = "us-east-2"
  type    = string
}

variable "aws_profile" {
  default = "default"
  type    = string
}

variable "bucket_name" {
  default = "lottery-api"
  type    = string
}

variable "docs_base_url" {
  default = "NOT_SET"
  type    = string
}

variable "https" {
  default = false
  type    = string
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

terraform {
  backend "s3" {}
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "Lottery"

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
      "Sid": ""
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "doc" {
  statement {
    effect = "Allow"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.main.arn,
      "${aws_s3_bucket.main.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "main" {
  name = "Lottery"
  policy = data.aws_iam_policy_document.doc.json
}

resource "aws_iam_role_policy_attachment" "lambda_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role = aws_iam_role.iam_for_lambda.name
}

resource "aws_iam_role_policy_attachment" "lambda_execution_custom" {
  policy_arn = aws_iam_policy.main.arn
  role = aws_iam_role.iam_for_lambda.name
}

resource "aws_lambda_function" "tfversion" {
  filename      = "../compiled/lambda_payload.zip"
  function_name = "Lottery"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "handler.handler"
  source_code_hash = filebase64sha256("../compiled/lambda_payload.zip")
  timeout = 500

  runtime = "nodejs10.x"

  environment {
    variables = {
      bucket_name = aws_s3_bucket.main.id
    }
  }

}

resource "aws_s3_bucket" "main" {
  bucket = var.bucket_name
  acl    = "public-read"

  website {
    index_document = "index.html"
  }
}

resource "aws_cloudwatch_event_rule" "run_lambda" {
  name        = "run_lottery"
  description = "runs the lottery api"

  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "run_lambda" {
  rule = aws_cloudwatch_event_rule.run_lambda.name
  target_id = "run_lambda_lottery"
  arn = aws_lambda_function.tfversion.arn
}

resource "aws_lambda_permission" "run_lambda" {
  statement_id = "AllowExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tfversion.function_name
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.run_lambda.arn
}