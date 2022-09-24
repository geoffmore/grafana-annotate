output "token" {
  value = length(grafana_service_account_token.this) == 0 ? null : grafana_service_account_token.this[0].key
  sensitive = true
}
