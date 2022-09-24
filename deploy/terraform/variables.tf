// Target Grafana URL, Required for aws_lambda_function.main
variable "grafana_url" {
  sensitive = true
}

// Auth according to https://registry.terraform.io/providers/grafana/grafana/latest/docs#auth. Admin basic role recommended
variable "grafana_auth" {
  sensitive = true
}

// Path to a zip archive containing the grafana-annotate golang executable. Overrides local.archive_path if present
variable "archive_path" {
  default = ""
}

/* Whether or not to provision the Grafana Data Source with full readonly access to CloudWatch logs/metrics as opposed to
  full access to CloudWatch metrics and scoped permissions to the provisioned logGroup for CloudWatch logs
*/
variable "cloudwatch_full_readonly" {
  type    = bool
  default = false
}

// Log retention for the provisioned CloudWatch Log Group
variable "log_retention" {
  type    = number
  default = 90
}
