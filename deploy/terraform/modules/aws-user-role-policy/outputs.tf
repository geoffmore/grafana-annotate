output "iam_user" {
  description = "IAM user name and arn"
  value = {
    name = aws_iam_user.this.name
    arn  = aws_iam_user.this.arn
  }
}
output "iam_role" {
  description = "IAM role name and arn"
  value = {
    name = aws_iam_role.this.name
    arn  = aws_iam_role.this.arn
  }
}
// Only output credentials if the iam_access_key exists
output "iam_credentials" {
  description = "AWS IAM Access Key in cases where var.iam_access_key is true"
  sensitive   = true
  // TODO - Get external eyes on this logic
  value = length(aws_iam_access_key.this) == 0 ? null : {
    id     = aws_iam_access_key.this[0].id
    secret = aws_iam_access_key.this[0].secret
  }
}
