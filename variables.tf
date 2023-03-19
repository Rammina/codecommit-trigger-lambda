variable "region" {
  type    = string
  default = "us-east-1"
}

variable "discord_webhook_url" {
  type      = string
  sensitive = true
}

variable "sns_emails" {
  type        = list(string)
  description = "List of emails to subscribe to the SNS topic. e.g. (['sub1@gmail.com', 'sub2@gmail.com', 'john@example.com'])"
  default     = []
}
