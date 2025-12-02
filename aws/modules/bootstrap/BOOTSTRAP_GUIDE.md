# AWS Bootstrap Guide

This guide details the **one-time manual steps** required to initialize your AWS environment. You must perform this "bootstrap" process locally to create the Terraform state backend and cross-account access roles.

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
region            = "us-east-1"
dev_account_id    = "123456789012"  # Replace with your Dev Account ID
prod_account_id   = "210987654321"  # Replace with your Prod Account ID
state_bucket_name = "my-org-terraform-state" # Unique S3 bucket name
lock_table_name   = "terraform-locks"
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

## Step 3: Verify Outputs
After the apply completes, you will see outputs similar to this:
```text
cross_account_role_arn = "arn:aws:iam::265245191272:role/TerraformStateAccessRole"
state_bucket_arn       = "arn:aws:s3:::my-org-terraform-state"
lock_table_arn         = "arn:aws:dynamodb:us-east-1:265245191272:table/terraform-locks"
```

These resources are now ready for use by your environments.

**Note:** GitHub Actions authentication is configured separately via the `github-oidc` module in the shared-account environment. See `docs/PIPELINE.md` for GitHub Actions setup.

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
2.  Commit your changes (including the new `backend.tf`) and push to GitHub.
3.  The GitHub Actions pipeline should now work with the remote state backend!

## Next Steps

After completing the bootstrap process, you should:
1. Set up GitHub OIDC authentication - see `docs/PIPELINE.md`
2. Configure GitHub Actions workflows
3. Deploy to dev and prod environments

See the main documentation for more details.
