terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.53"
    }
  }
}

provider "aws" {
  profile = "karthick"
  region  = "us-east-1"
}

locals {
  account_id          = data.aws_caller_identity.current.account_id
  region              = data.aws_region.current.name
  restore_testing_arn = "arn:aws:backup:${local.region}:${local.account_id}:restore-testing-plan:"
}


resource "aws_iam_role" "lambda_role" {
  name = "iam_for_lambda"

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

resource "aws_iam_policy" "iam_policy_for_lambda" {

  name        = "aws_iam_policy_for_terraform_aws_lambda_role"
  path        = "/"
  description = "AWS IAM Policy for managing aws lambda role"
  policy      = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": [
       "logs:CreateLogGroup",
       "logs:CreateLogStream",
       "logs:PutLogEvents"
     ],
     "Resource": "arn:aws:logs:*:*:*",
     "Effect": "Allow"
   }
 ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.iam_policy_for_lambda.arn
}

data "archive_file" "zip_the_python_code" {
  type        = "zip"
  source_dir  = "${path.module}/python/"
  output_path = "${path.module}/python/hello-python.zip"
}

resource "aws_lambda_function" "terraform_lambda_func" {
  filename      = "${path.module}/python/hello-python.zip"
  function_name = "june14_Test_Lambda_Function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.8"
  depends_on    = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role]
}

resource  "aws_lambda_invocation" "example" {
  function_name = aws_lambda_function.terraform_lambda_func.function_name
  input = jsonencode({
    db_host = "db.host.com"
    db_port = "5432"
    username = "test" 
    action = "mydbuser",
    # "tf": {
    # "action": "delete",
    # }
  })
  #lifecycle_scope = "CRUD"
  depends_on = [ aws_lambda_function.terraform_lambda_func ]
  }

data  "aws_lambda_invocation" "example1" {
  count  = var.destroy ? 1 : 0
  function_name = aws_lambda_function.terraform_lambda_func.function_name
  input = jsonencode({
    db_host = "db.host.com"
    db_port = "5432"
    username = "test" 
    action = "mydbuser",
    value = jsondecode(aws_lambda_invocation.example.result)
    # "tf": {
    # "action": "delete",
    # }
  })
  #lifecycle_scope = "CRUD"
  depends_on = [ aws_lambda_function.terraform_lambda_func,
  aws_lambda_invocation.example ]
  }

#   output "result_entry" {
#   value = jsondecode(aws_lambda_invocation.example[count.index].result)
# }




# resource "aws_s3_bucket" "example" {
#   count  = var.destroy ? 1 : 0
#   bucket = "my-tf-test-bucket-jun14_2"

#   tags = {
#     Name        = "My bucket"
#     Environment = "Dev"
#   }
# }

# resource "aws_cloudwatch_event_rule" "cloudwatch-rule" {
#   name        = "cloudwatch-rule-test"
#   description = "Alarms based on glue crawler"
#   event_pattern = jsonencode({
#     "detail-type": ["Glue Crawler State Change"],
#     "source": ["aws.glue"],
#     "detail": {
#       "crawlerName": [{"prefix": local.restore_testing_arn}],
#       "state": ["Succeeded"]
#     }
#   })
# }

# resource "aws_cloudwatch_event_target" "step_function_event_target" {
#   target_id = "test-1234"
#   rule      = aws_cloudwatch_event_rule.cloudwatch-rule.name
#   arn       = "arn:aws:lambda:us-east-1:550257769522:function:event-trigger-lambda-may16" #"<step function arn>"
#   #role_arn  = <role that allows eventbridge to start execution on your behalf>
# }

# resource "aws_lambda_permission" "awesome-lambda-perm" {
#   action        = "lambda:InvokeFunction"
#   function_name = "event-trigger-lambda-may16" #aws_lambda_function.awesome-lambda.function_name
#   principal     = "events.amazonaws.com"
#   source_arn    = aws_cloudwatch_event_rule.cloudwatch-rule.arn
# }


