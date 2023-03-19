terraform {
  # Configure the required Terraform version and plugins. 
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
}

# Define the AWS provider and region.
provider "aws" {
  region = var.region
}

# Lambda function to handle SNS notifications 
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "lambda/"
  output_path = "/tmp/lambda.zip"
}

# IAM role for the Lambda function 
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]

  }
}

# CodeCommit repository to store our code. 
resource "aws_codecommit_repository" "simple_code_commit" {
  repository_name = "simple-code-commit"
  default_branch  = "master"
}

# Approval rule template requiring approval from the SeniorDevs IAM group 
# for pushes to the master branch. This ensures code review before changes are deployed. 
resource "aws_codecommit_approval_rule_template" "senior_devs_approval" {
  name        = "senior_devs_approval"
  description = "This approval rule template requires approval from the SeniorDevs IAM group for pushes to the master branch."

  content = jsonencode({
    Version               = "2018-11-08"
    DestinationReferences = ["refs/heads/master"]
    Statements = [{
      Type                    = "Approvers"
      NumberOfApprovalsNeeded = 1
      ApprovalPoolMembers     = ["arn:aws:sts::285741065100:assumed-role/SeniorDevs/*"]
    }]
  })
}

# Associate the approval rule template with the CodeCommit repository 
resource "aws_codecommit_approval_rule_template_association" "senior_devs_approval" {
  repository_name             = aws_codecommit_repository.simple_code_commit.repository_name
  approval_rule_template_name = aws_codecommit_approval_rule_template.senior_devs_approval.name
}

# SNS topic to send notifications for repository triggers 
resource "aws_sns_topic" "repo_notifications" {
  name = "repo_notifications"
}

# CodeCommit trigger to subscribe to all repository events and send notifications to the SNS topic 
resource "aws_codecommit_trigger" "repo_trigger" {
  repository_name = aws_codecommit_repository.simple_code_commit.repository_name
  trigger {
    name            = "all-events"
    events          = ["all"]                              # All repository events 
    destination_arn = aws_sns_topic.repo_notifications.arn # SNS topic ARN 
    branches        = ["master"]                           # Branch filter 
  }
}

# SNS email subscriptions for the repository notifications 
resource "aws_sns_topic_subscription" "repo_notifications_email" {

  for_each  = toset(var.sns_emails)
  topic_arn = aws_sns_topic.repo_notifications.arn
  protocol  = "email"
  endpoint  = each.value
}

# IAM role for the Lambda function 
resource "aws_iam_role" "lambda_exec" {
  name               = "lambda_exec"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# Give the Lambda role an additional policy for writing to Amazon CloudWatch Logs 
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda layer with Node.js packages
resource "aws_lambda_layer_version" "layer" {
  filename   = "dependencies/lambda-layer.zip"
  layer_name = "discord_notification_layer"

  compatible_runtimes = ["nodejs18.x"]
}

# Lambda function to send notifications to Discord
resource "aws_lambda_function" "discord_notification" {
  filename      = data.archive_file.lambda.output_path
  function_name = "discord_notification"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambda.handle_sns"

  runtime = "nodejs18.x"
  timeout = 30

  layers = [aws_lambda_layer_version.layer.arn]

  environment {
    variables = {
      DISCORD_WEBHOOK_URL = var.discord_webhook_url
    }
  }
}

# Subscribe the Lambda function to the SNS topic 
resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = aws_sns_topic.repo_notifications.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.discord_notification.arn
}

# Event rule to trigger the Lambda function for any AWS CodeCommit events 
resource "aws_cloudwatch_event_rule" "codecommit_events" {
  name = "codecommit_events"
  event_pattern = jsonencode(
    {
      source : ["aws.codecommit"],
      detail-type : ["CodeCommit Repository State Change"],
      detail : {
        event : ["referenceCreated", "referenceUpdated", "referenceDeleted"],
        referenceType : ["branch"],
        referenceName : ["master"],
        repositoryId : [aws_codecommit_repository.simple_code_commit.repository_id]
      }
    }
  )
}

# Associates the CloudWatch event rule with the Lambda function so it is invoked on CodeCommit events 
resource "aws_cloudwatch_event_target" "codecommit_to_lambda" {
  rule      = aws_cloudwatch_event_rule.codecommit_events.name
  target_id = "codecommit_to_lambda"
  arn       = aws_lambda_function.discord_notification.arn
}
