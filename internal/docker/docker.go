package docker

import (
	"fmt"
	"os/exec"
	"strings"
)

// CheckDockerRunning verifies if Docker daemon is running
func CheckDockerRunning() error {
	cmd := exec.Command("docker", "info")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("docker daemon is not running: %w", err)
	}
	return nil
}

// ComposeUp starts the Docker Compose stack with the specified env file
func ComposeUp(envFile string) error {
	cmd := exec.Command("docker", "compose", "--env-file", envFile, "up", "-d", "--wait")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to start docker compose stack: %w\nOutput: %s", err, string(output))
	}
	return nil
}

// ComposeDown stops the Docker Compose stack
func ComposeDown(envFile string) error {
	cmd := exec.Command("docker", "compose", "--env-file", envFile, "down")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to stop docker compose stack: %w\nOutput: %s", err, string(output))
	}
	return nil
}

// CreateVolume creates a Docker volume if it doesn't exist
func CreateVolume(name string) error {
	// Check if volume exists
	cmd := exec.Command("docker", "volume", "inspect", name)
	if err := cmd.Run(); err == nil {
		return nil // Volume already exists
	}

	// Create volume
	cmd = exec.Command("docker", "volume", "create", name)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to create volume %s: %w", name, err)
	}
	return nil
}

// RemoveContainer removes a Docker container by name if it exists
func RemoveContainer(name string) error {
	// Check if container exists
	cmd := exec.Command("docker", "ps", "-a", "--format", "{{.Names}}")
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to list containers: %w", err)
	}

	containers := strings.Split(string(output), "\n")
	exists := false
	for _, container := range containers {
		if container == name {
			exists = true
			break
		}
	}

	if !exists {
		return nil
	}

	// Remove container
	cmd = exec.Command("docker", "rm", "-f", name)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to remove container %s: %w", name, err)
	}
	return nil
}
