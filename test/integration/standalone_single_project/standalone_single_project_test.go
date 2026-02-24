/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package standalone_single_project

import (
	"fmt"
	"strings"
	"testing"

	// "time" // Uncomment if using RetryableErrors or Polling

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"

	// "github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/utils" // Uncomment if using Polling
	"github.com/stretchr/testify/assert"
	"github.com/tidwall/gjson"
)

// Helper function to check if a specific member has a specific role in an IAM policy JSON array
func assertHasRole(assert *assert.Assertions, bindings []gjson.Result, role string, expectedMember string, resourceName string) {
	found := false
	for _, binding := range bindings {
		if binding.Get("role").String() == role {
			for _, member := range binding.Get("members").Array() {
				if member.String() == expectedMember {
					found = true
					break
				}
			}
		}
	}
	assert.True(found, fmt.Sprintf("Role '%s' should be granted to '%s' on %s", role, expectedMember, resourceName))
}

func TestStandaloneSingleProjectExample(t *testing.T) {

	// 1. Initialize the Setup Environment
	setupOutput := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../setup"))
	projectID := setupOutput.GetStringOutput("project_id")
	// If you added outputs to the setup module (like network details), grab them here.

	// 2. Define Variables for the Main Module
	vars := map[string]interface{}{
		"project_id": projectID,
		"region":     "us-central1", // Or pull from setup if dynamic
		// Add other necessary variables that your standalone_single_project requires
	}

	// 3. Initialize the Main Blueprint Test
	standaloneSingleProjT := tft.NewTFBlueprintTest(t,
		tft.WithVars(vars),
		tft.WithTFDir("../../../examples/standalone_single_project"),
		// tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute), // Highly recommended if you copy the testutils package
	)

	// 4. Define the Custom Verifier
	standaloneSingleProjT.DefineVerify(func(assert *assert.Assertions) {
		// Perform default verification ensuring Terraform reports no additional changes
		// standaloneSingleProjT.DefaultVerify(assert)

		// Fetch Outputs
		region := standaloneSingleProjT.GetStringOutput("region")
		garRepoName := standaloneSingleProjT.GetStringOutput("gar_repo")
		pipelineFullID := standaloneSingleProjT.GetStringOutput("clouddeploy_pipeline_id")

		// Parse the pipeline name from the full ID string
		pipelineParts := strings.Split(pipelineFullID, "/")
		pipelineName := pipelineParts[len(pipelineParts)-1]

		buildSAEmail := fmt.Sprintf("serviceAccount:%s", standaloneSingleProjT.GetStringOutput("build_sa_email"))
		deploySAEmail := fmt.Sprintf("serviceAccount:%s", standaloneSingleProjT.GetStringOutput("deploy_sa_email"))

		// Handle the comma-separated cluster names
		clusterNamesString := standaloneSingleProjT.GetStringOutput("cluster_names")
		clusterNames := strings.Split(clusterNamesString, ",")
		assert.NotEmpty(clusterNamesString, "cluster_names output should not be empty")

		// ====================================================================
		// A. Artifact Registry Verification
		// ====================================================================
		garCommand := fmt.Sprintf("artifacts repositories describe %s --location=%s --project=%s --format=json", garRepoName, region, projectID)
		garResult := gcloud.Run(t, garCommand)

		assert.Equal("DOCKER", garResult.Get("format").String(), "Artifact Registry format should be DOCKER")

		// ====================================================================
		// B. Cloud Deploy Pipeline Verification
		// ====================================================================
		deployCommand := fmt.Sprintf("deploy delivery-pipelines describe %s --region=%s --project=%s --format=json", pipelineName, region, projectID)
		deployResult := gcloud.Run(t, deployCommand)

		assert.False(deployResult.Get("suspended").Bool(), "Cloud Deploy pipeline should be active (not suspended)")

		stages := deployResult.Get("serialPipeline.stages").Array()
		assert.NotEmpty(stages, "Cloud Deploy pipeline should have at least one stage configured")

		// ====================================================================
		// C. GKE Clusters Security Posture Verification
		// ====================================================================
		for _, clusterName := range clusterNames {
			if clusterName == "" {
				continue
			}

			clusterCmd := fmt.Sprintf("container clusters describe %s --region=%s --project=%s --format=json", clusterName, region, projectID)
			clusterResult := gcloud.Run(t, clusterCmd)

			// Cluster Status
			assert.Equal("RUNNING", clusterResult.Get("status").String(), fmt.Sprintf("Cluster %s should be RUNNING", clusterName))

			// Network Security: Ensure private nodes
			isPrivate := clusterResult.Get("privateClusterConfig.enablePrivateNodes").Bool()
			assert.True(isPrivate, fmt.Sprintf("Cluster %s should have private nodes enabled", clusterName))

			// Workload Identity Posture
			expectedWorkloadPool := fmt.Sprintf("%s.svc.id.goog", projectID)
			assert.Equal(expectedWorkloadPool, clusterResult.Get("workloadIdentityConfig.workloadPool").String(), fmt.Sprintf("Cluster %s workloadPool should be configured securely", clusterName))

			// Binary Authorization Posture
			binAuthzMode := clusterResult.Get("binaryAuthorization.evaluationMode").String()
			assert.Equal("PROJECT_SINGLETON_POLICY_ENFORCE", binAuthzMode, fmt.Sprintf("Binary Authorization should be enforced on cluster %s", clusterName))

			// Shielded Nodes Posture
			shieldedNodes := clusterResult.Get("shieldedNodes.enableSecureBoot").Bool()
			assert.True(shieldedNodes, fmt.Sprintf("Shielded Nodes Secure Boot should be enabled on cluster %s", clusterName))
		}

		// ====================================================================
		// D. IAM & Principle of Least Privilege Verification
		// ====================================================================

		// 1. Fetch Project-level IAM policy
		projectIamCmd := fmt.Sprintf("projects get-iam-policy %s --format=json", projectID)
		projectIam := gcloud.Run(t, projectIamCmd)
		projectBindings := projectIam.Get("bindings").Array()

		// 2. Fetch GAR-level IAM policy
		garIamCmd := fmt.Sprintf("artifacts repositories get-iam-policy %s --location=%s --project=%s --format=json", garRepoName, region, projectID)
		garIamResult := gcloud.Run(t, garIamCmd)
		garBindings := garIamResult.Get("bindings").Array()

		// Assert CI Pipeline (Build SA) Permissions
		assertHasRole(assert, garBindings, "roles/artifactregistry.writer", buildSAEmail, "Artifact Registry")
		// (Assume KMS is bound at project level for this example, adjust if bound to key)
		assertHasRole(assert, projectBindings, "roles/cloudkms.signerVerifier", buildSAEmail, "Project (KMS Signer)")

		// Assert CD Pipeline (Deploy SA) Permissions
		assertHasRole(assert, projectBindings, "roles/clouddeploy.jobRunner", deploySAEmail, "Project (Cloud Deploy Runner)")
		assertHasRole(assert, projectBindings, "roles/container.developer", deploySAEmail, "Project (GKE Developer)")

	})

	// Optional: Define custom teardown if necessary (e.g., deleting leftover Cloud Build artifacts or GAR images)
	// standaloneSingleProjT.DefineTeardown(func(assert *assert.Assertions) { ... })

	// 5. Execute the Test
	standaloneSingleProjT.Test()
}
