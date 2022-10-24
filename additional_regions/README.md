## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_rule.reporting](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.reporting](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.reporting](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_lambda_function.reporting](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.reporting](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [terraform_remote_state.waf](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deployment_tool"></a> [deployment\_tool](#input\_deployment\_tool) | Tool used to configure service | `string` | `"terraform"` | no |
| <a name="input_env_name"></a> [env\_name](#input\_env\_name) | Name of the envrionment | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region to deploy to | `string` | n/a | yes |
| <a name="input_repository_name"></a> [repository\_name](#input\_repository\_name) | Repo name | `string` | `"well-architected-reporting"` | no |
| <a name="input_service_name"></a> [service\_name](#input\_service\_name) | Name of the service being deployed | `string` | `"well-architected-reporting"` | no |
| <a name="input_team"></a> [team](#input\_team) | Team managing the service | `string` | n/a | yes |

## Outputs

No outputs.
