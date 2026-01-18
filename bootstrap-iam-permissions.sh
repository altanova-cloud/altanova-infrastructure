#!/bin/bash
# Bootstrap script to add IAM tagging permissions to deployment roles
# This is a ONE-TIME operation to fix the chicken-and-egg problem

set -e

echo "🔧 Bootstrapping IAM Tagging Permissions for Deployment Roles"
echo "=============================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to add permissions to a role
add_iam_tagging_permissions() {
    local role_name=$1
    local account_id=$2
    local environment=$3

    echo "📝 Adding IAM tagging permissions to ${role_name} in account ${account_id} (${environment})..."

    # Create the policy document
    cat > /tmp/iam-tagging-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:TagRole",
        "iam:UntagRole",
        "iam:TagPolicy",
        "iam:UntagPolicy"
      ],
      "Resource": "*"
    }
  ]
}
EOF

    # Attach the policy to the role (inline policy)
    aws iam put-role-policy \
        --role-name "${role_name}" \
        --policy-name "IAMTaggingPermissions" \
        --policy-document file:///tmp/iam-tagging-policy.json \
        --profile "altanova-${environment}" \
        2>/dev/null || {
            echo -e "${RED}❌ Failed to add permissions to ${role_name}${NC}"
            echo "   Make sure you have AWS CLI configured with admin access to the ${environment} account"
            return 1
        }

    echo -e "${GREEN}✅ Successfully added IAM tagging permissions to ${role_name}${NC}"
    echo ""
}

# Main execution
echo "This script will add IAM tagging permissions to:"
echo "  - DevDeployRole  (Dev Account: 975050047325)"
echo "  - ProdDeployRole (Prod Account: 624755517249)"
echo ""
echo -e "${YELLOW}Prerequisites:${NC}"
echo "  1. AWS CLI installed and configured"
echo "  2. AWS profiles named: altanova-dev, altanova-prod"
echo "  3. Admin access to both Dev and Prod accounts"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""

# Add permissions to Dev account
add_iam_tagging_permissions "DevDeployRole" "975050047325" "dev"

# Add permissions to Prod account
add_iam_tagging_permissions "ProdDeployRole" "624755517249" "prod"

# Cleanup
rm -f /tmp/iam-tagging-policy.json

echo "=============================================================="
echo -e "${GREEN}✅ Bootstrap completed successfully!${NC}"
echo ""
echo "Next steps:"
echo "  1. Retry the failed GitHub Actions workflow"
echo "  2. The deployment should now succeed"
echo "  3. Terraform will manage these permissions going forward"
echo ""
