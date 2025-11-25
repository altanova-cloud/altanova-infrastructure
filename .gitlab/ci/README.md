# GitLab CI/CD Configuration Structure

This directory contains modular CI/CD configuration files for better organization and maintainability.

## File Structure

```
.gitlab/ci/
├── security.yml        # Security scanning jobs (Checkov, tfsec)
└── README.md          # This file
```

## Files

### `security.yml`
**Purpose**: Security scanning and SAST (Static Application Security Testing)

**Jobs**:
- `checkov-scan`: Terraform security scanning with Checkov
- `tfsec-scan`: Terraform security scanning with tfsec

**Maintained by**: Security/DevSecOps team

**Configuration files**:
- `.checkov.yaml` - Checkov configuration
- `.tfsec.yml` - tfsec configuration

---

## How It Works

The main `.gitlab-ci.yml` file includes these modular files:

```yaml
include:
  - local: '.gitlab/ci/security.yml'
```

This allows:
- ✅ Better organization
- ✅ Easier maintenance
- ✅ Clear ownership
- ✅ Reduced merge conflicts
- ✅ Reusability across projects

---

## Adding New Modules

To add a new CI/CD module:

1. Create a new file: `.gitlab/ci/your-module.yml`
2. Add jobs to the file
3. Include it in `.gitlab-ci.yml`:
   ```yaml
   include:
     - local: '.gitlab/ci/security.yml'
     - local: '.gitlab/ci/your-module.yml'
   ```

---

## Future Modules (Recommended)

Consider splitting into these modules as the pipeline grows:

- `terraform.yml` - Terraform plan/apply jobs
- `templates.yml` - Reusable job templates
- `notifications.yml` - Slack/email notifications
- `testing.yml` - Automated testing jobs
- `deployment.yml` - Deployment-specific jobs

---

## Best Practices

1. **One responsibility per file** - Each file should have a clear purpose
2. **Document ownership** - Add comments about who maintains each file
3. **Use templates** - Define reusable templates in `templates.yml`
4. **Version control** - Track changes to individual files
5. **Test changes** - Use `gitlab-ci-lint` to validate before pushing

---

## References

- [GitLab CI/CD Include Documentation](https://docs.gitlab.com/ee/ci/yaml/includes.html)
- [GitLab CI/CD Best Practices](https://docs.gitlab.com/ee/ci/pipelines/pipeline_efficiency.html)
