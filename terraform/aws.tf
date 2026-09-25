# ---- AWS: LLM + knowledge base layer ----
# S3 holds the knowledge-base docs. Lambda calls Bedrock to draft the reply
# and searches S3 for the best-matching doc to recommend.

resource "aws_s3_bucket" "knowledge_base" {
  bucket = var.s3_bucket_name
}

resource "aws_s3_bucket_public_access_block" "kb_block" {
  bucket                  = aws_s3_bucket.knowledge_base.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../aws-lambda"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_iam_role" "lambda_exec" {
  name = "ai-agent-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "bedrock_access" {
  name = "bedrock-invoke-policy"
  role = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["bedrock:InvokeModel"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy" "s3_read" {
  name = "s3-read-policy"
  role = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        aws_s3_bucket.knowledge_base.arn,
        "${aws_s3_bucket.knowledge_base.arn}/*"
      ]
    }]
  })
}

resource "aws_lambda_function" "draft_reply" {
  function_name    = "ai-agent-draft-reply"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      KB_BUCKET        = aws_s3_bucket.knowledge_base.bucket
      BEDROCK_MODEL_ID = "anthropic.claude-3-haiku-20240307-v1:0"
    }
  }
}

# Function URL = simplest way to call Lambda over HTTP with no API Gateway
resource "aws_lambda_function_url" "draft_reply_url" {
  function_name      = aws_lambda_function.draft_reply.function_name
  authorization_type = "NONE" # demo simplicity only - see README hardening notes
}

output "lambda_function_url" {
  value = aws_lambda_function_url.draft_reply_url.function_url
}

output "s3_bucket" {
  value = aws_s3_bucket.knowledge_base.bucket
}
