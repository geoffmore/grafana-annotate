// The name of the service account to provision
variable "name" {}

// The basic role for the service account according to https://grafana.com/docs/grafana/latest/administration/roles-and-permissions/#roles-and-permissions
variable "basic_role" {}

// Whether or not to provision and output a token for the created service account. Output will be sensitive
variable "token" {
  type    = bool
  default = false
}
