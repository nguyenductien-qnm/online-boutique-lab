# Online Boutique ECR repositories

Creates one immutable, scan-on-push ECR repository per microservice under the
`online-boutique/` namespace. This stack does not manage GitHub OIDC or IAM.

## Usage

Authenticate the configured AWS profile, then run:

```bash
cd infra/ecr
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan -out=ecr.tfplan
terraform apply ecr.tfplan
```

Review the plan before applying. Expected result: 12 repositories created in
`ap-southeast-1` and no IAM resources changed.

List repository URLs after apply:

```bash
terraform output repository_urls
```

Images should use immutable Git commit tags rather than `latest`:

```text
730335441285.dkr.ecr.ap-southeast-1.amazonaws.com/online-boutique/frontend:<git-sha>
```

Commit `.terraform.lock.hcl` after `terraform init`. Never commit Terraform
state or plan files.
