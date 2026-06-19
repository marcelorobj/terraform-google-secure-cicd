// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package harness_vpcsc

import (
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/terraform-google-modules/terraform-google-secure-cicd/test/integration/testutils"
)

func TestVPCSC(t *testing.T) {
	vpcPath := "../../setup/harness/service_perimeter"

	setupOutput := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../setup"))
	projectID := setupOutput.GetStringOutput("project_id_standalone")
	projectNumber := setupOutput.GetStringOutput("project_number_standalone")
	serviceAccount := setupOutput.GetTFSetupStringOutput("sa_email")
	addAccessLevelMembers := strings.Split(os.Getenv("TF_VAR_access_level_members"), ",")
	protected_projects := []string{}

	accessLevelMembers := []string{
		fmt.Sprintf("serviceAccount:%s", serviceAccount),
		"serviceAccount:cloud-build@system.gserviceaccount.com",
		fmt.Sprintf("serviceAccount:service-%s@gcp-sa-cloudbuild.iam.gserviceaccount.com", projectNumber),
	}
	accessLevelMembers = append(accessLevelMembers, addAccessLevelMembers...)
	t.Logf("accessLevelMembers: %v", accessLevelMembers)
	vars := map[string]interface{}{
		"access_level_members": accessLevelMembers,
		"protected_projects":   protected_projects,
		"project_id":           projectID,
	}

	vpcsc := tft.NewTFBlueprintTest(t,
		tft.WithTFDir(vpcPath),
		tft.WithVars(vars),
		tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
		tft.WithParallelism(100),
	)
	vpcsc.Test()

}

func TestCleanVPCSC(t *testing.T) {
	vpcPath := "../../setup/harness/service_perimeter"
	temp := tft.NewTFBlueprintTest(t, tft.WithTFDir(vpcPath))
	orgID := temp.GetTFSetupStringOutput("organization_id")
	testutils.CleanOrgACMPolicyID(t, orgID)
	if testutils.GetOrgACMPolicyID(t, orgID) == "" {
		_, err := testutils.CreateOrgACMPolicyID(t, orgID)
		if err != nil {
			t.Logf("Error creating the ACM policy: %s", err)
		}
	}
}
