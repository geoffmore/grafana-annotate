terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = ">= 1.29.0"
    }
  }
}

resource "grafana_service_account" "this" {
  name = var.name
  role = var.basic_role
}

resource "grafana_service_account_token" "this" {
  count = var.token ? 1 : 0
  name = var.name
  service_account_id = grafana_service_account.this.id
}

// TODO - find a way to determine the license level of a Grafana instance

// TODO - allow additional granular fixed roles for an Enterprise-level Grafana instance

// TODO - find a way to verify that the grafana instance is recent enough to have service account APIs
