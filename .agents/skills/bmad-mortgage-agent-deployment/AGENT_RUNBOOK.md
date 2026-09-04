# Agent Runbook: Mortgage Agent Deployment

This runbook guides the agent in deploying the mortgage-agent example.

---

# Stage 1: Prerequisites

### 1.1: Welcome & Introduction
- Greet the user and briefly explain the purpose of this skill.

### 1.2: Configure Git Credential Helper
- Run `git config --global credential.helper gcloud.sh` to configure Git to use gcloud credentials for authenticating to Google Cloud Source Repositories.

### 1.3: Check gcloud Authentication
- Run `gcloud auth print-access-token` to check for active credentials.
- If it fails, instruct the user to run `gcloud auth login` and `gcloud auth application-default login`.

### 1.3: Confirm GCP Project
- Run `gcloud config get-value project` to find the currently configured project.
- If a project is found, ask the user for confirmation: "I've detected the project '[PROJECT_NAME]' is configured. Do you want to use this one for the deployment?".
- If the user agrees, proceed. If the user disagrees, or if no project was initially configured, prompt the user to enter the correct Project ID.
- Run `gcloud config set project [CHOSEN_PROJECT_ID]` to ensure the correct project is active for all subsequent commands.

### 1.4: Check for Public DNS Zone
- Ask the user if they have a public DNS zone.
- If not, provide instructions on how to create one using Google Cloud Domains.

### 1.5: Check for Organization Policies
- Run `gcloud resource-manager org-policies describe constraints/gcp.restrictNonCmekServices --project=[PROJECT_ID]`.
- If the policy is enforced, halt and explain the blocker.
- Handle `PERMISSION_DENIED` errors gracefully.

---

# Stage 2: Configuration

### 2.1: Gather Configuration Values
- **User-Provided Values:** Prompt the user for the following information:
    - **CRITICAL NOTE:** The repository names will also be used to create Cloud Build triggers. These trigger names do NOT support underscores (`_`). Therefore, when asking for repository names, use hyphens (`-`) instead and inform the user of this convention.
    - Public DNS Domain Name (e.g., `example.com`).
    - Terraform Service Account Email.
    - **The URLs for the 6 required Git repositories.** The agent must explain that for each of the three microservices, a separate repository for Continuous Integration (CI - source code) and Continuous Delivery (CD - deployment configs) is required, and then ask for them individually:
        - **Legacy DMS Service:**
            - CI Repository URL (e.g., `https://github.com/user/legacy-dms-ci.git`)
            - CD Repository URL (e.g., `https://github.com/user/legacy-dms-cd.git`)
        - **Corporate Email Service:**
            - CI Repository URL (e.g., `https://github.com/user/corporate-email-ci.git`)
            - CD Repository URL (e.g., `https://github.com/user/corporate-email-cd.git`)
        - **Income Verification Service:**
            - CI Repository URL (e.g., `https://github.com/user/income-verification-ci.git`)
            - CD Repository URL (e.g., `https://github.com/user/income-verification-cd.git`)
    - The names (not the values) of the Secret Manager secrets for the GitHub PAT and App ID.

- **Automatically-Derived Values:** The agent will obtain the following values programmatically:
    - `project_id`: From the project confirmed in Stage 1.3.
    - `project_number`: By running `gcloud projects describe [PROJECT_ID] --format='value(projectNumber)'`.
    - `org_id`: By running `gcloud projects get-ancestors [PROJECT_ID] --format='get(id)'` and extracting the organization ID.

### 2.2: Generate terraform.tfvars
- Read the content of the `examples/mortgage-agent/terraform.example.tfvars` template file.
- Programmatically replace the placeholder values using the variables gathered in Stage 2.1. This includes `project_id`, `project_number`, `org_id`, `dns_zone_domain`, the domain in `mcp_internal_dns_zone`, repository URLs, and secret names.
- **CRITICAL RULE:** Do NOT modify the `image` attribute for any service in the `mcp_services` map. The value `"us-docker.pkg.dev/cloudrun/container/placeholder"` is the correct, final value and must be preserved.
- Save the final, generated content to `examples/mortgage-agent/terraform.tfvars`.

---

# Stage 3: Infrastructure Provisioning

### 3.1: Terraform Plan
- Change directory to `examples/mortgage-agent`.
- Run `terraform init`.
- Run `terraform plan -out=tfplan`.
- Save the plan output to a file and show it to the user.
- Ask for explicit approval to proceed.

### 3.2: Terraform Apply
- Execute o script `.agents/skills/bmad-mortgage-agent-deployment/scripts/01-terraform-apply.sh` a partir do diretório raiz do projeto.

### 3.3: Extract Terraform Outputs
- Run `terraform output -json` and save the output.

---

# Stage 4: Application Deployment

### 4.1: Seed Repositories and Deploy
- Execute o script `.agents/skills/bmad-mortgage-agent-deployment/scripts/02-git-ops-and-adk.sh` a partir do diretório raiz do projeto, passando as URLs dos repositórios de CI/CD como variáveis de ambiente.

### 4.2: Final Status
- Report the final status of the deployment to the user.

---

# Stage 5: Agent Deployment and Permissions

### 5.1: Deploy the Agent
- Change directory to `examples/mortgage-agent/src/mortgage_agent`.
- Run `uv sync` to install dependencies.
- Extract the necessary values from the Terraform outputs (`project_id`, `region`, `agent_gateway_id`, `mcp_invoker_sa`).
- Construct and run the `deploy_agent.py` command:
  ```bash
  uv run python deploy_agent.py \
  --project=[PROJECT_ID] \
  --region=[REGION] \
  --enable-agent-identity \
  --agent-name=mortgage-agent \
  --agent-gateway=[AGENT_GATEWAY_ID] \
  --mcp-invoker-sa=[MCP_INVOKER_SA] \
  --model-endpoint-location=global
  ```
- Capture the `AGENT_ID` from the output.

### 5.2: Grant Agent Egress Permissions
- Change directory back to the root of the project.
- Run the `grant_agent_mcp_egress.sh` script to grant permissions for all agents to all endpoints.
  ```bash
  ./scripts/grant_agent_mcp_egress.sh --bind-all-agents --endpoints
  ```
- Run the script again to grant the specific agent unconditional access to `legacy-dms` and `income-verification`.
  ```bash
  ./scripts/grant_agent_mcp_egress.sh \
     --mcp \
     --agent-id [AGENT_ID] \
     --mcp-filter "legacy-dms income-verification"
  ```
- Run the script a final time to grant conditional access to `corporate-email`.
  ```bash
  ./scripts/grant_agent_mcp_egress.sh \
     --mcp \
     --agent-id [AGENT_ID] \
     --mcp-filter "corporate-email" \
     --condition-expression "api.getAttribute('iap.googleapis.com/mcp.tool.isReadOnly', false) == true || api.getAttribute('iap.googleapis.com/mcp.toolName','')==''" \
     --condition-title "ReadOnlyToolsOnly" \
     --condition-description "Restrict [AGENT_ID] to read-only tools on corporate-email"
  ```

### 5.3: Final Report
- Inform the user that the agent is fully deployed and ready for testing in the Agent Platform Playground.
