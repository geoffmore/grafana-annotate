data "aws_caller_identity" "this" {}

resource "aws_iam_user" "this" {
  name = var.iam_user
  tags = var.tags
}

resource "aws_iam_role" "this" {
  name_prefix = var.iam_user
  assume_role_policy = templatefile("${path.module}/templates/role-principals.json.tmpl",
    {
      user    = aws_iam_user.this.name
      account = data.aws_caller_identity.this.id
    }
  )
  # Let Terraform manage all parts of role's policies
  inline_policy {}
  tags = var.tags
}

resource "aws_iam_policy" "this" {
  name        = aws_iam_user.this.name
  description = "IAM policy for user '${aws_iam_user.this.name}'"
  // Assume policy handling has been done in the calling module.
  policy = var.iam_policy
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  role = aws_iam_role.this.name
  # TODO - discover a way to attach multiple policies to a single user
  policy_arn = aws_iam_policy.this.arn

}

// The credentials will exist in your statefile!
resource "aws_iam_access_key" "this" {
  count = var.iam_access_key ? 1 : 0

  user = aws_iam_user.this.name
}
