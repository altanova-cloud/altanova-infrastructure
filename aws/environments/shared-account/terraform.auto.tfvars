# Auto-loaded variables for shared account
# Sensitive values should be set via CI/CD variables
region              = "us-east-1"
dev_account_id      = "975050047325"
prod_account_id     = "624755517249"
gitlab_project_path = "altanova/altanova-infrastructure"
state_bucket_name   = "altanova-tf-state-eu-central-1"
lock_table_name     = "altanova-terraform-locks"

# GitHub OIDC configuration
github_org         = "altanova-cloud"
github_repo        = "altanova-infrastructure"
github_oidc_provider_arn = "arn:aws:iam::265245191272:oidc-provider/token.actions.githubusercontent.com"
