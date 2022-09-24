terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = ">= 1.29.0"
    }
    aws = {
      version = ">= 4.31.0"
    }
  }
}
