variable "region" {
  type    = string
  default = "us-east-1"
}

variable "discord_webhook_url" {
  type      = string
  sensitive = true
}
