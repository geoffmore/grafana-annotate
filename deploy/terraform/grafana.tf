
provider "grafana" {
  url  = var.grafana_url
  auth = var.grafana_auth
}

/* TODO - determine how to allow access to enterprise roles for enterprise instances.
  "Editor" is always required for non-enterprise. "Viewer" + "annotations:create" with scope "annotations:type:" can be used for enterprise
  Maybe grafana_is_enterprise drives the workflow
  Role assignments require a role uid and no datasource exists as of provider 1.29.0
*/


locals {
  cloudwatch_full_ro_policy = file("${path.module}/templates/cloudwatch-full-readonly-policy.json")
  cloudwatch_scoped_ro_policy = templatefile("${path.module}/templates/cloudwatch-scoped-policy.json.tmpl",
    {
      account  = local.aws_account
      region   = local.aws_region
      logGroup = local.log_group
  })
}

module "grafana_iam" {
  source = "./modules/aws-user-role-policy"

  iam_user = "grafana-cloudwatch"
  // Required true. IAM Access Key and Secret Access Key will live in your statefile
  iam_access_key = true
  /* Based on https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazoncloudwatch.html,
  no additional filtering is possible on the metrics in the scoped CloudWatch policy
  */
  // The full policy works for logs, the scoped one does not
  iam_policy = var.cloudwatch_full_readonly == true ? local.cloudwatch_full_ro_policy : local.cloudwatch_scoped_ro_policy
  tags       = local.global_tags
}

// TODO - prevent illegal access by only provisioning this if grafana_iam.iam_access_key is true
// Maybe a count is sufficient here
resource "grafana_data_source" "cloudwatch" {
  name = var.cloudwatch_full_readonly == true ? "Full ReadOnly - ${local.function_name}" : "Lambda Logs/Metrics - ${local.function_name}"
  //name = var.grafana_data_source
  type = "cloudwatch"

  // TODO - complain about the field change from snake case to camel case in Grafana 9.0+
  json_data_encoded = jsonencode({
    assumeRoleArn = module.grafana_iam.iam_role.arn
    /* https://github.com/grafana/terraform-provider-grafana/blob/c48423921f64bd3f6e91dd028b0d6c8d800ada02/grafana/resource_data_source_test.go#L364
      only has the the single auth type in tests and Grafana Cloud has the one value in the dropdown,
      so this will be static for now
      https://registry.terraform.io/providers/grafana/grafana/latest/docs/resources/data_source#profile
      challenges this
    */
    authType         = "keys"
    defaultRegion    = local.aws_region
    defaultLogGroups = [local.log_group]
  })

  secure_json_data_encoded = jsonencode({
    accessKey = module.grafana_iam.iam_credentials.id
    secretKey = module.grafana_iam.iam_credentials.secret
  })
}

// TODO - Fancy Dashboard bundling logs/metrics for the Lambda
