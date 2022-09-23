data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  aws_account = data.aws_caller_identity.current.id
  aws_region  = data.aws_region.current.name
}

locals {
  global_tags = {
    managed_by = "Terraform"
    app        = local.function_name
  }
}
// Future variables for the module
locals {
  function_name = "grafana-post-annotations"
  role_name     = "lambda-${local.function_name}"
  ecr_repository_name = "grafana-api/post-annotations"
}

locals {
  // Defined in the Makefile at the root of the repo. Overriden by var.archive_path
  archive_path = "${path.root}/grafana-annotate.zip"
}

resource "aws_lambda_function" "main" {
  function_name = local.function_name
  role          = aws_iam_role.lambda.arn

  description  = "Expose the Grafana Annotations API (https://grafana.com/docs/grafana/v9.0/developers/http_api/annotations/) as serverless function"

  /* This is required initially to successfully provision the lambda
  since an ECR repository, even if created, will not be populated
  */
  // run 'make tf-plan' to generate the necessary zip file
  // See https://docs.aws.amazon.com/lambda/latest/dg/golang-package.html for requirements
  // START 'Zip' package_type
  package_type = "Zip"
  handler = "grafana-annotate"
  runtime      = "go1.x"
  filename = var.archive_path == "" ? local.archive_path : var.archive_path
  // END 'Zip' package_type
  // Uncomment this instead to reference a private, populated ECR registry
  /*
  // START 'Image' package_type
  package_type = "Image"
  image_uri = "${aws_ecr_repository.main.repository_url}:<your-image-tag>"
  // END 'Image' package_type
  */

  // TODO - determine how to handle multiple versions of the lambda
  publish      = false

  environment {
    variables = {
      GRAFANA_URL   = var.grafana_url
      GRAFANA_TOKEN = var.grafana_token
    }
  }

  // TODO - conditionally make this tag present when the type is zip
  tags = merge(
    local.global_tags,
    {
      // See https://stackoverflow.com/questions/33825815
      archive_base64sha256 = filebase64sha256(local.archive_path)
    }
  )
}

resource "aws_lambda_function_url" "main" {
  function_name      = aws_lambda_function.main.function_name
  authorization_type = "NONE"
  // Set this to proxy behind a domain. Implementation is left to the reader
  //cors {}
}

resource "aws_lambda_permission" "public" {
  statement_id_prefix           = "FunctionURLAllowPublicAccess"
  action                 = "lambda:InvokeFunctionURL"
  function_name          = aws_lambda_function.main.function_name
  function_url_auth_type = aws_lambda_function_url.main.authorization_type
  principal              = "*"
}

# TODO - Verify aws-urp module with iam access key enabled and disabled

// TODO - Verify that cloudwatch metrics are implicitly generated for lambdas

// TODO - Determine if restricting principals on the lambda role trusted entities is necessary

resource "aws_iam_role" "lambda" {
  name               = local.role_name
  assume_role_policy = templatefile("${path.module}/templates/lambda-role-principals.json.tmpl", {})

  tags = merge(
    local.global_tags,
    {}
  )
}

// See https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazoncloudwatchlogs.html
resource "aws_iam_policy" "lambda_logs" {
  policy = templatefile("${path.module}/templates/lambda-policy-logs.json.tmpl", {
    region   = local.aws_region
    account  = local.aws_account
    logGroup = "/aws/lambda/${local.function_name}"
  })

  tags = merge(
    local.global_tags,
    {}
  )
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  policy_arn = aws_iam_policy.lambda_logs.arn
  role       = aws_iam_role.lambda.name
}
