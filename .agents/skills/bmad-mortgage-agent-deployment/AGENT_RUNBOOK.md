# Agent Runbook: Mortgage Agent Deployment

This runbook guides the agent in deploying the mortgage-agent example.

---

# Stage 1: Prerequisites

### 1.1: Welcome & Introduction
- Greet the user and briefly explain the purpose of this skill.

### 1.2: Check gcloud Authentication
- Run `gcloud auth print-access-token` to check for active credentials.
- If it fails, instruct the user to run `gcloud auth login` and `gcloud auth application-default login`.

### 1.3: Check GCP Project
- Run `gcloud config get-value project` to check for an active project.
- If not set, ask the user for their GCP Project ID and run `gcloud config set project [PROJECT_ID]`.

### 1.4: Check for Public DNS Zone
- Ask the user if they have a public DNS zone.
- If not, provide instructions on how to create one using Google Cloud Domains.

### 1.5: Check for Organization Policies
- Run `gcloud resource-manager org-policies describe constraints/gcp.restrictNonCmekServices --project=[PROJECT_ID]`.
- If the policy is enforced, halt and explain the blocker.
- Handle `PERMISSION_DENIED` errors gracefully.

---

# Stage 2: Configuration

### 2.1: Gather Terraform Variables
- Prompt the user for all required variables for the `terraform.tfvars` file.
- Sanitize and validate inputs, especially the 6 unique Git repository URLs.

### 2.2: Create terraform.tfvars
- Create the `terraform.tfvars` file in the `examples/mortgage-agent` directory.

---

# Stage 3: Infrastructure Provisioning

### 3.1: Terraform Plan
- Change directory to `examples/mortgage-agent`.
- Run `terraform init`.
- Run `terraform plan -out=tfplan`.
- Save the plan output to a file and show it to the user.
- Ask for explicit approval to proceed.

### 3.2: Terraform Apply
- Execute `scripts/01-terraform-apply.sh`.

### 3.3: Extract Terraform Outputs
- Run `terraform output -json` and save the output.

---

# Stage 4: Application Deployment

### 4.1: Seed Repositories and Deploy
- Execute `scripts/02-git-ops-and-adk.sh`, passing the Terraform outputs as environment variables.

### 4.2: Final Status
- Report the final status of the deployment to the user.
