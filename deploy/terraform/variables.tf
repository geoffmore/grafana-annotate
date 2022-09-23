// Target Grafana URL, Required for aws_lambda_function.main
variable "grafana_url" {
  sensitive = true
}
// Grafana auth token, Required for aws_lambda_function.main
variable "grafana_token" {
  sensitive = true
}

// Path to a zip archive containing the grafana-annotate golang executable. Overrides local.archive_path if present
variable "archive_path" {
  default = ""
}

