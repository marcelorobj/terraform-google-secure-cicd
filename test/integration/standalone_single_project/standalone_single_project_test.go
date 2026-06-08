// Copyright 2026 Google LLC
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

package standalone_single_project

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/git"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/stretchr/testify/assert"
	"github.com/terraform-google-modules/terraform-google-secure-cicd/test/integration/testutils"
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

func runCmd(t *testing.T, dir, name string, args ...string) {
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	t.Logf("Running command in %s: %s %v", dir, name, args)
	if err := cmd.Run(); err != nil {
		t.Fatalf("Command failed in %s: %s %v, error: %v", dir, name, args, err)
	}
}

func setupGitOperations(t *testing.T, bpFolder, wsFolder, ciRepoName string, cdRepoName string) {
	t.Log("Starting Git Operations Setup...")

	gitLabPath := "../../setup/harness/gitlab"
	gitLab := tft.NewTFBlueprintTest(t, tft.WithTFDir(gitLabPath))
	gitUrl := gitLab.GetStringOutput("gitlab_url")
	gitlabPersonalTokenSecretName := gitLab.GetStringOutput("gitlab_pat_secret_name")
	gitlabSecretProject := gitLab.GetStringOutput("gitlab_secret_project")

	token, err := testutils.GetSecretFromSecretManager(t, gitlabPersonalTokenSecretName, gitlabSecretProject)
	if err != nil {
		t.Fatal(err)
	}

	hostNameWithPath := strings.Split(gitUrl, "https://")[1]
	ciRepoUrl := fmt.Sprintf("https://oauth2:%s@%s/root/%s", token, hostNameWithPath, ciRepoName)
	cdRepoUrl := fmt.Sprintf("https://oauth2:%s@%s/root/%s", token, hostNameWithPath, cdRepoName)

	// Configure Git
	runCmd(t, wsFolder, "git", "config", "--global", "user.email", "test-user@example.com")
	runCmd(t, wsFolder, "git", "config", "--global", "user.name", "Test User")

	cdRepoLocalPath := filepath.Join(wsFolder, cdRepoName)

	cdGit := git.NewCmdConfig(t, git.WithDir(wsFolder))
	cdGitRun := func(args ...string) {
		_, err := cdGit.RunCmdE(args...)
		if err != nil {
			t.Fatalf("CD Git command failed in %s: %v", wsFolder, err)
		}
	}

	cdGitRun("clone", cdRepoUrl, cdRepoLocalPath)
	cdGit = git.NewCmdConfig(t, git.WithDir(cdRepoLocalPath))
	cdGitRun = func(args ...string) {
		_, err := cdGit.RunCmdE(args...)
		if err != nil {
			t.Fatalf("CD Git command failed in %s: %v", cdRepoLocalPath, err)
		}
	}
	cdGitRun("checkout", "-b", "main")

	cfdYamlDest := filepath.Join(cdRepoLocalPath, "cloudbuild-cd.yaml")
	runCmd(t, bpFolder, "cp", "/workspace/build/cloudbuild-cd.yaml", cfdYamlDest)

	cdGitRun("add", ".")
	cdGit.CommitWithMsg("initial commit", []string{"--allow-empty"})
	cdGitRun("push", "origin", "main", "--force")

	appRepoLocalPath := filepath.Join(wsFolder, "bank-of-anthos")

	appGit := git.NewCmdConfig(t, git.WithDir(wsFolder))
	appGitRun := func(args ...string) {
		_, err := appGit.RunCmdE(args...)
		if err != nil {
			t.Fatalf("CI Git command failed in %s: %v", wsFolder, err)
		}
	}

	appGitRun("clone", "--branch", "v0.5.11", "https://github.com/GoogleCloudPlatform/bank-of-anthos.git", appRepoLocalPath)
	appGit = git.NewCmdConfig(t, git.WithDir(appRepoLocalPath))
	appGitRun = func(args ...string) {
		_, err := appGit.RunCmdE(args...)
		if err != nil {
			t.Fatalf("Git command failed in %s: %v", appRepoLocalPath, err)
		}
	}
	appGitRun("checkout", "-b", "main")

	ciYamlDest := filepath.Join(appRepoLocalPath, "cloudbuild-ci.yaml")
	runCmd(t, bpFolder, "cp", "/workspace/build/cloudbuild-ci.yaml", ciYamlDest)

	policiesDest := filepath.Join(appRepoLocalPath, "policies")
	runCmd(t, bpFolder, "cp", "-R", "/workspace/build/policies", policiesDest)

	appGitRun("remote", "add", "gitlab", ciRepoUrl)
	appGitRun("add", ".")
	appGit.CommitWithMsg("initial commit", []string{"--allow-empty"})
	appGitRun("push", "gitlab", "main", "--force")
	t.Log("Finished Git Operations Setup.")
}

func TestStandaloneSingleProjectExample(t *testing.T) {

	setupOutput := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../setup"))
	projectID := setupOutput.GetStringOutput("project_id_standalone")
	region := setupOutput.GetStringOutput("primary_location")

	blueprintFolder := ("../../../../")

	workspaceFolder, err := os.MkdirTemp("/tmp", "workspace-*")
	if err != nil {
		t.Fatalf("Failed to create temporary workspace: %v", err)
	}
	log.Printf("Created workspace folder: %s", workspaceFolder)
	defer os.RemoveAll(workspaceFolder)

	vars := map[string]interface{}{
		"project_id": projectID,
		"region":     region,
	}

	standaloneSingleProjT := tft.NewTFBlueprintTest(t,
		tft.WithVars(vars),
		tft.WithTFDir("../../../examples/standalone_single_project"),
	)

	standaloneSingleProjT.DefineVerify(func(assert *assert.Assertions) {

		ciRepoName := standaloneSingleProjT.GetStringOutput("ci_repo_name")
		cdRepoName := standaloneSingleProjT.GetStringOutput("cd_repo_name")
		setupGitOperations(t, blueprintFolder, workspaceFolder, ciRepoName, cdRepoName)

		standaloneSingleProjT.DefaultVerify(assert)
	})

	// 5. Execute the Test
	standaloneSingleProjT.Test()
}
