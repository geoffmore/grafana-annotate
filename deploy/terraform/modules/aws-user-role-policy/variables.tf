// Name of the created IAM user
variable "iam_user" {}

// Tags set on applicable resources
variable "tags" {
  default = {}
}

// IAM policy document
variable "iam_policy" {}

// Determines whether or not an IAM Access Key is provisioned for the IAM user. Access Key will exist in the statefile
variable "iam_access_key" {
  type    = bool
  default = false
}
