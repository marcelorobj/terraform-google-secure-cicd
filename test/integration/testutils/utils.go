package testutils

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/shell"
)

// GetSecretFromSecretManager retrieves the latest version of a secret from Google Cloud Secret Manager using the gcloud CLI.
func GetSecretFromSecretManager(t *testing.T, secretName string, secretProject string) (string, error) {
	t.Log("Retrieving secret from secret manager.")
	cmd := fmt.Sprintf("secrets versions access latest --project=%s --secret=%s", secretProject, secretName)
	args := strings.Fields(cmd)
	gcloudCmd := shell.Command{
		Command: "gcloud",
		Args:    args,
		Logger:  logger.Discard,
	}
	return shell.RunCommandAndGetStdOutE(t, gcloudCmd)
}

// ReplacePatternInTfVars will walk directories searching for terraform.tfvars and replace the pattern with the replacement
func ReplacePatternInTfVars(pattern string, replacement string, root string) error {
	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, fnErr error) error {
		if fnErr != nil {
			return fnErr
		}
		if !d.IsDir() && d.Name() == "terraform.tfvars" {
			return replaceInFile(path, pattern, replacement)
		}
		return nil
	})

	return err
}

// ReplacePatternInFile will walk directories searching for fileName and replace the pattern with the replacement
func ReplacePatternInFile(pattern string, replacement string, root string, fileName string) error {
	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, fnErr error) error {
		if fnErr != nil {
			return fnErr
		}
		if !d.IsDir() && d.Name() == fileName {
			return replaceInFile(path, pattern, replacement)
		}
		return nil
	})

	return err
}

// replaceInFile will replace oldPattern in filePath with newPattern
func replaceInFile(filePath, oldPattern, newPattern string) error {
	fileInfo, err := os.Lstat(filePath)
	if err != nil {
		return err
	}

	if fileInfo.Mode()&os.ModeSymlink != 0 {
		fmt.Printf("%s is a symlink, will skip the pattern replacement.", filePath)
		return nil
	} else {
		content, err := os.ReadFile(filePath)
		if err != nil {
			return err
		}

		newContent := strings.ReplaceAll(string(content), oldPattern, newPattern)

		err = os.WriteFile(filePath, []byte(newContent), 0644)
		if err != nil {
			return err
		}

		fmt.Printf("Updated file: %s\n", filePath)

		return nil
	}
}
