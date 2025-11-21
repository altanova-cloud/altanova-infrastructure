# AWS Bootstrap Guide

This guide details the **one-time manual steps** required to initialize your AWS environment. You must perform this "bootstrap" process locally to create the IAM roles that GitLab CI/CD will use.

## Prerequisites
1.  **Initial IAM Role**: You must have an IAM Role in the **Shared Account** with sufficient permissions (e.g., `AdministratorAccess` or `S3FullAccess`, `IAMFullAccess`, and `DynamoDBFullAccess`) to run the initial deployment.
2.  **AWS CLI**: Installed and configured to assume this initial role.
    *   **Critical**: Run `aws sts get-caller-identity` to verify you are authenticated as this role in the Shared Account before proceeding.
3.  **Terraform**: Installed locally.

## Step 1: Configure Variables
Navigate to the shared account directory:
```bash
cd landing-zones/aws/environments/shared-account
```

Create a `terraform.tfvars` file with your specific values:
```hcl
# terraform.tfvars
region              = "us-east-1"
dev_account_id      = "123456789012"  # Replace with your Dev Account ID
prod_account_id     = "210987654321"  # Replace with your Prod Account ID
gitlab_project_path = "my-group/my-project" # Replace with your GitLab project path
state_bucket_name   = "my-org-terraform-state" # Unique S3 bucket name
lock_table_name     = "terraform-locks"
```

## Step 2: Deploy Locally
### Option A: Using Local Terraform (Recommended)
Initialize Terraform with a local backend (default):
```bash
terraform init
```

Apply the configuration:
```bash
terraform apply
```

### Option B: Using Docker Compose (If Terraform is not installed)
If you don't have Terraform installed, you can use Docker Compose.

1.  **Ensure `docker-compose.yaml` exists** in the directory with the following content:
    ```yaml
    version: '3.7'
    services:
      tf:
        image: hashicorp/terraform:1.7
        volumes:
          - ../../../:/project
        working_dir: /project/aws/environments/shared-account
        environment:
          - AWS_ACCESS_KEY_ID
          - AWS_SECRET_ACCESS_KEY
          - AWS_SESSION_TOKEN
    ```

2.  **Initialize**:
    ```bash
    # Pass your AWS credentials via environment variables
    aws-vault exec sharedou-ro -- docker-compose run --rm tf init
    ```
    *Or if you have credentials exported in your shell:*
    ```bash
    docker-compose run --rm tf init
    ```

3.  **Apply**:
    ```bash
    docker-compose run --rm tf apply
    ```
*Type `yes` when prompted.*

## Step 3: Configure GitLab CI/CD
After the apply completes, you will see outputs similar to this:
```text
gitlab_oidc_role_arn = "arn:aws:iam::111111111111:role/GitLabRunnerRole"
state_bucket_arn     = "arn:aws:s3:::my-org-terraform-state"
...
```

1.  Copy the `gitlab_oidc_role_arn`.
2.  Go to your **GitLab Project Settings** > **CI/CD** > **Variables**.
3.  Add a new variable:
    *   **Key**: `AWS_ROLE_ARN`
    *   **Value**: *(Paste the ARN you copied)*
    *   **Type**: Variable
    *   **Protected**: Yes (Recommended)
    *   **Masked**: No (ARNs usually cannot be masked)

## Step 4: Enable Remote State (Important!)
Now that the S3 bucket exists, you must configure Terraform to use it.

1.  Create a `backend.tf` file in `landing-zones/aws/environments/shared-account/`:
    ```hcl
    terraform {
      backend "s3" {
        bucket         = "my-org-terraform-state" # Match your terraform.tfvars
        key            = "shared-account/terraform.tfstate"
        region         = "us-east-1"
        dynamodb_table = "terraform-locks"
        encrypt        = true
      }
    }
    ```
2.  Migrate your local state to S3:
    ```bash
    terraform init -migrate-state
    ```
    *Type `yes` to confirm.*

## Step 5: Commit and Push
1.  Delete the local `terraform.tfstate` and `terraform.tfstate.backup` files (optional, as state is now in S3).
2.  Commit your changes (including the new `backend.tf`) and push to GitLab.
3.  The pipeline should now run successfully!
